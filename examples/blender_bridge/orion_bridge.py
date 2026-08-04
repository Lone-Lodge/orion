# Orion bridge, Blender side. A tiny line-delimited JSON server: receive
# {"code": "..."}, run it (on the main thread when the GUI is up), reply
# {"ok": 0|1, "output": "...", "error": "..."} and close the connection.
# In the GUI every request also lands in the "Orion" sidebar panel (N key),
# newest first, so the session is readable from inside Blender.
#
# Three ways to run it:
#   Blender add-on: Edit > Preferences > Add-ons > Install, enable "Orion Bridge"
#   blender --background --python orion_bridge.py   (headless, blocks)
#   python orion_bridge.py                          (no bpy - protocol test)

import contextlib
import io
import json
import socket
import threading
import time
import traceback

HOST = "127.0.0.1"
PORT = 4777
HISTORY_MAX = 50

try:
    import bpy
except ImportError:
    bpy = None

bl_info = {
    "name": "Orion Bridge",
    "author": "Lone Lodge",
    "version": (1, 1),
    "blender": (4, 2, 0),
    "description": "Kor Python skickad fran Orion-bryggan over en lokal socket",
    "category": "Development",
}


def run_code(code):
    captured = io.StringIO()
    scope = {"bpy": bpy}
    try:
        with contextlib.redirect_stdout(captured):
            exec(code, scope)
        return {"ok": 1, "output": captured.getvalue(), "error": ""}
    except Exception:
        return {"ok": 0, "output": captured.getvalue(), "error": traceback.format_exc()}


# --- the sidebar log (GUI only) ---

history = []  # {"when", "ok", "code", "output"} - newest last


def record(code, reply):
    shown = reply["output"] if reply["ok"] else reply["error"]
    history.append({
        "when": time.strftime("%H:%M:%S"),
        "ok": reply["ok"],
        "code": code.strip(),
        "output": shown.strip(),
    })
    del history[:-HISTORY_MAX]
    for window in bpy.context.window_manager.windows:
        for area in window.screen.areas:
            if area.type == "VIEW_3D":
                area.tag_redraw()


class ORION_OT_clear_log(bpy.types.Operator if bpy else object):
    bl_idname = "orion.clear_log"
    bl_label = "Rensa loggen"

    def execute(self, context):
        history.clear()
        return {"FINISHED"}


class ORION_PT_bridge(bpy.types.Panel if bpy else object):
    bl_label = "Orion Bridge"
    bl_space_type = "VIEW_3D"
    bl_region_type = "UI"
    bl_category = "Orion"

    def draw(self, context):
        layout = self.layout
        head = layout.row()
        running = _server is not None
        head.label(text=f"{HOST}:{PORT}", icon="LINKED" if running else "UNLINKED")
        head.operator("orion.clear_log", text="", icon="TRASH")
        if not history:
            layout.label(text="Inget kort an.")
            return
        for entry in reversed(history):
            box = layout.box()
            row = box.row()
            row.label(text=f"{entry['when']}  {entry['code'][:38]}",
                      icon="CHECKMARK" if entry["ok"] else "CANCEL")
            for out_line in entry["output"].splitlines()[:4]:
                box.label(text=out_line[:52])


# bpy is not thread-safe: in GUI mode the code runs via a timer on Blender's
# main thread while the server thread waits.
def run_on_main_thread(code):
    finished = threading.Event()
    result = {}

    def on_timer():
        result.update(run_code(code))
        record(code, result)
        finished.set()
        return None

    bpy.app.timers.register(on_timer)
    if not finished.wait(30):
        return {"ok": 0, "output": "", "error": "timeout: main thread never ran the code (30 s)"}
    return result


def handle_connection(connection):
    data = b""
    while not data.endswith(b"\n"):
        chunk = connection.recv(65536)
        if not chunk:
            break
        data += chunk
    if not data:
        connection.close()
        return
    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError:
        text = data.decode("cp1252")  # Windows ANSI argv (an 'ä' on the command line)
    try:
        # a Windows pipe (PowerShell 5.1) prepends a BOM to piped code
        code = json.loads(text)["code"].lstrip(chr(0xfeff))
    except (ValueError, KeyError):
        reply = {"ok": 0, "output": "", "error": 'bad request: expected {"code": "..."}'}
    else:
        gui = bpy is not None and not bpy.app.background
        reply = run_on_main_thread(code) if gui else run_code(code)
    connection.sendall((json.dumps(reply) + "\n").encode("utf-8"))
    connection.close()


_server = None


def serve():
    global _server
    _server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    _server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    _server.bind((HOST, PORT))
    _server.listen(4)
    print(f"[orion-bridge] listening on {HOST}:{PORT}")
    while True:
        try:
            connection, _address = _server.accept()
        except OSError:
            break  # socket closed by unregister()
        try:
            handle_connection(connection)
        except OSError:
            pass  # a dropped client must not kill the server


def register():
    if bpy is not None:
        bpy.utils.register_class(ORION_OT_clear_log)
        bpy.utils.register_class(ORION_PT_bridge)
    threading.Thread(target=serve, daemon=True).start()


def unregister():
    if bpy is not None:
        bpy.utils.unregister_class(ORION_PT_bridge)
        bpy.utils.unregister_class(ORION_OT_clear_log)
    if _server is not None:
        _server.close()


if __name__ == "__main__":
    if bpy is not None and not bpy.app.background:
        register()  # blender --python: the GUI keeps running, serve alongside it
    else:
        serve()  # headless blender or plain python: block here
