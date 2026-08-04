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
    bl_description = "Tom aktivitetsloggen"

    def execute(self, context):
        history.clear()
        return {"FINISHED"}


class ORION_OT_copy_output(bpy.types.Operator if bpy else object):
    bl_idname = "orion.copy_output"
    bl_label = "Kopiera senaste svar"
    bl_description = "Lagg senaste korningens output pa urklipp"

    def execute(self, context):
        if history:
            latest = history[-1]
            context.window_manager.clipboard = latest["output"] or latest["code"]
        return {"FINISHED"}


class ORION_PT_bridge(bpy.types.Panel if bpy else object):
    bl_label = "Orion Bridge"
    bl_space_type = "VIEW_3D"
    bl_region_type = "UI"
    bl_category = "Orion"

    def draw(self, context):
        layout = self.layout
        running = _server is not None
        status = layout.row(align=True)
        status.label(text=f"Server {HOST}:{PORT}",
                     icon="LINKED" if running else "UNLINKED")
        if not history:
            hint = layout.column()
            hint.active = False
            hint.label(text="Inget kort an.")
            return
        fails = sum(1 for entry in history if not entry["ok"])
        summary = layout.row(align=True)
        count = summary.row()
        count.active = False
        count.label(text=f"{len(history)} korningar, {fails} fel")
        summary.operator("orion.copy_output", text="", icon="COPYDOWN")
        summary.operator("orion.clear_log", text="", icon="TRASH")
        log = layout.column(align=True)
        for entry in reversed(history):
            box = log.box()
            head = box.row(align=True)
            head.alert = not entry["ok"]
            code_line = entry["code"].splitlines()[0] if entry["code"] else ""
            head.label(text=f"{entry['when']}  {code_line[:34]}",
                       icon="CHECKMARK" if entry["ok"] else "CANCEL")
            if entry["output"]:
                body = box.column(align=True)
                body.active = False  # dimmed: output is secondary to the code line
                for out_line in entry["output"].splitlines()[:3]:
                    body.label(text=out_line[:52])


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
        bpy.utils.register_class(ORION_OT_copy_output)
        bpy.utils.register_class(ORION_PT_bridge)
    threading.Thread(target=serve, daemon=True).start()


def unregister():
    if bpy is not None:
        bpy.utils.unregister_class(ORION_PT_bridge)
        bpy.utils.unregister_class(ORION_OT_copy_output)
        bpy.utils.unregister_class(ORION_OT_clear_log)
    if _server is not None:
        _server.close()


if __name__ == "__main__":
    if bpy is not None and not bpy.app.background:
        register()  # blender --python: the GUI keeps running, serve alongside it
    else:
        serve()  # headless blender or plain python: block here
