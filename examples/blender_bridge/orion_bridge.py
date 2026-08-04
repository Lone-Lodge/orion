# Orion bridge, Blender side. A tiny line-delimited JSON server: receive
# {"code": "..."}, run it (on the main thread when the GUI is up), reply
# {"ok": 0|1, "output": "...", "error": "..."} and close the connection.
#
# The "Orion" tab in the 3D-view sidebar (N key) is the cockpit: a chat field
# that talks to the claude CLI (headless, --continue, cwd = CHAT_DIR so the
# conversation and its permissions live with the bridge), quick actions, and
# a log of everything the bridge ran - newest first.
#
# Three ways to run it:
#   Blender add-on: Edit > Preferences > Add-ons > Install, enable "Orion Bridge"
#   blender --background --python orion_bridge.py   (headless, blocks)
#   python orion_bridge.py                          (no bpy - protocol test)

import contextlib
import io
import json
import shutil
import socket
import subprocess
import threading
import time
import traceback

HOST = "127.0.0.1"
PORT = 4777
HISTORY_MAX = 50
CHAT_DIR = r"C:\Users\User\Desktop\llstudios\orion\examples\blender_bridge"
CREATE_NO_WINDOW = 0x08000000

try:
    import bpy
except ImportError:
    bpy = None

bl_info = {
    "name": "Orion Bridge",
    "author": "Lone Lodge",
    "version": (1, 2),
    "blender": (4, 2, 0),
    "description": "Claude-chat, snabbknappar och logg for Orion-bryggan",
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

history = []  # {"when", "ok", "kind", "code", "output"} - newest last


def redraw():
    for window in bpy.context.window_manager.windows:
        for area in window.screen.areas:
            if area.type == "VIEW_3D":
                area.tag_redraw()


def record(code, reply):
    shown = reply["output"] if reply["ok"] else reply["error"]
    history.append({
        "when": time.strftime("%H:%M:%S"),
        "ok": reply["ok"],
        "kind": "code",
        "code": code.strip(),
        "output": shown.strip(),
    })
    del history[:-HISTORY_MAX]
    redraw()


# --- chat: the panel talks to the claude CLI ---

def chat_worker(prompt, entry):
    exe = shutil.which("claude")
    if exe is None:
        ok, text = 0, "hittar inte claude-CLI:t pa PATH"
    else:
        try:
            # --continue keeps one ongoing Blender conversation; the first
            # message ever has nothing to continue, so retry without it.
            run = subprocess.run([exe, "-c", "-p", prompt], cwd=CHAT_DIR,
                                 capture_output=True, text=True, encoding="utf-8",
                                 errors="replace", timeout=600,
                                 creationflags=CREATE_NO_WINDOW)
            if run.returncode != 0:
                run = subprocess.run([exe, "-p", prompt], cwd=CHAT_DIR,
                                     capture_output=True, text=True, encoding="utf-8",
                                     errors="replace", timeout=600,
                                     creationflags=CREATE_NO_WINDOW)
            ok = 1 if run.returncode == 0 else 0
            text = (run.stdout if ok else (run.stderr or run.stdout)).strip()
        except (OSError, subprocess.TimeoutExpired) as failure:
            ok, text = 0, str(failure)

    def apply():
        entry["ok"] = ok
        entry["output"] = text
        entry["when"] = time.strftime("%H:%M:%S")
        redraw()
        return None

    bpy.app.timers.register(apply)


class ORION_OT_chat_send(bpy.types.Operator if bpy else object):
    bl_idname = "orion.chat_send"
    bl_label = "Skicka till Claude"
    bl_description = "Skicka meddelandet till Claude (claude-CLI:t, samma konversation)"

    def execute(self, context):
        prompt = context.window_manager.orion_prompt.strip()
        if not prompt:
            return {"CANCELLED"}
        context.window_manager.orion_prompt = ""
        entry = {"when": time.strftime("%H:%M:%S"), "ok": 1, "kind": "chat",
                 "code": f"Du: {prompt}", "output": "... vantar pa Claude"}
        history.append(entry)
        del history[:-HISTORY_MAX]
        redraw()
        threading.Thread(target=chat_worker, args=(prompt, entry), daemon=True).start()
        return {"FINISHED"}


# --- quick actions ---

class ORION_OT_clear_scene(bpy.types.Operator if bpy else object):
    bl_idname = "orion.clear_scene"
    bl_label = "Rensa scenen?"
    bl_description = "Tar bort allt utom kameror och ljus"

    def invoke(self, context, event):
        return context.window_manager.invoke_confirm(self, event)

    def execute(self, context):
        doomed = [obj for obj in context.scene.objects
                  if obj.type not in ("CAMERA", "LIGHT")]
        for obj in doomed:
            bpy.data.objects.remove(obj, do_unlink=True)
        return {"FINISHED"}


class ORION_OT_toggle_rendered(bpy.types.Operator if bpy else object):
    bl_idname = "orion.toggle_rendered"
    bl_label = "Renderad vy"
    bl_description = "Vaxla viewporten mellan solid och renderad"

    def execute(self, context):
        shading = context.space_data.shading
        shading.type = "SOLID" if shading.type == "RENDERED" else "RENDERED"
        return {"FINISHED"}


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
        chat = layout.row(align=True)
        chat.prop(context.window_manager, "orion_prompt", text="", icon="OUTLINER_OB_ARMATURE")
        chat.operator("orion.chat_send", text="", icon="PLAY")

        quick = layout.grid_flow(columns=2, align=True)
        quick.operator("wm.save_mainfile", text="Spara", icon="FILE_TICK")
        quick.operator("orion.toggle_rendered", text="Rendera", icon="SHADING_RENDERED")
        quick.operator("view3d.view_all", text="Visa allt", icon="ZOOM_ALL")
        quick.operator("orion.clear_scene", text="Rensa scen", icon="TRASH")

        status = layout.row(align=True)
        running = _server is not None
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
                shown_lines = 12 if entry.get("kind") == "chat" else 3
                body = box.column(align=True)
                body.active = False  # dimmed: output is secondary to the code line
                for out_line in entry["output"].splitlines()[:shown_lines]:
                    box_line = body.row()
                    box_line.label(text=out_line[:52])


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


classes = (ORION_OT_chat_send, ORION_OT_clear_scene, ORION_OT_toggle_rendered,
           ORION_OT_clear_log, ORION_OT_copy_output, ORION_PT_bridge)


def register():
    if bpy is not None:
        for panel_class in classes:
            bpy.utils.register_class(panel_class)
        bpy.types.WindowManager.orion_prompt = bpy.props.StringProperty(
            name="", description="Meddelande till Claude")
    threading.Thread(target=serve, daemon=True).start()


def unregister():
    if bpy is not None:
        for panel_class in reversed(classes):
            bpy.utils.unregister_class(panel_class)
        del bpy.types.WindowManager.orion_prompt
    if _server is not None:
        _server.close()


if __name__ == "__main__":
    if bpy is not None and not bpy.app.background:
        register()  # blender --python: the GUI keeps running, serve alongside it
    else:
        serve()  # headless blender or plain python: block here
