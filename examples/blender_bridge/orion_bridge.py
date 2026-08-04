# Orion bridge, Blender side. A tiny line-delimited JSON server: receive
# {"code": "..."}, run it (on the main thread when the GUI is up), reply
# {"ok": 0|1, "output": "...", "error": "..."} and close the connection.
#
# The "Claude" tab in the 3D-view sidebar (N key) is the cockpit:
#   Snabbt   - fixed actions + "kor igen" rows from recent bridge runs
#   Kontext  - checkboxes for what scene data rides along with each prompt
#   Chat     - one feed: your bubbles, Claude's replies, code blocks with
#              Kor/Kopiera, and dimmed action rows for every bridge run
#
# Three ways to run it:
#   Blender add-on: Edit > Preferences > Add-ons > Install, enable "Claude Bridge"
#   blender --background --python orion_bridge.py   (headless, blocks)
#   python orion_bridge.py                          (no bpy - protocol test)

import contextlib
import io
import json
import shutil
import socket
import subprocess
import textwrap
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
    "name": "Claude Bridge",
    "author": "Lone Lodge",
    "version": (1, 4),
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


# --- the feed (GUI only) ---

history = []  # {"id", "when", "ok", "kind", "code", "output", ...} - newest last
_next_id = [0]
last_model = [""]  # e.g. "sonnet" - shown next to the session tokens


def take_id():
    _next_id[0] += 1
    return _next_id[0]


def redraw():
    for window in bpy.context.window_manager.windows:
        for area in window.screen.areas:
            if area.type == "VIEW_3D":
                area.tag_redraw()


def record(code, reply):
    shown = reply["output"] if reply["ok"] else reply["error"]
    history.append({
        "id": take_id(),
        "when": time.strftime("%H:%M:%S"),
        "ok": reply["ok"],
        "kind": "code",
        "code": code.strip(),
        "output": shown.strip(),
    })
    del history[:-HISTORY_MAX]
    redraw()


def entry_by_id(entry_id):
    for entry in history:
        if entry["id"] == entry_id:
            return entry
    return None


# --- chat: the panel talks to the claude CLI ---

# First fenced code block out, prose (with the fence removed) stays as text.
def extract_snippet(text):
    if "```" not in text:
        return "", text
    parts = text.split("```")
    block = parts[1]
    if "\n" in block:
        first_line, rest = block.split("\n", 1)
        code = rest if first_line.strip() in ("python", "py", "") else block
    else:
        code = block
    prose = (parts[0] + "\n" + "\n".join(parts[2::2])).strip()
    return code.strip(), prose


def chat_worker(prompt, entry):
    exe = shutil.which("claude")
    tokens = 0
    meta = ""
    snippet = ""
    if exe is None:
        ok, text = 0, "hittar inte claude-CLI:t pa PATH"
    else:
        try:
            # --continue keeps one ongoing Blender conversation; the first
            # message ever has nothing to continue, so retry without it.
            # json output carries the reply plus usage (tokens, duration).
            brief = ("Du ar assistenten INNE i Blender. Blender kor redan med "
                     "Claude Bridge-addonet aktivt. Kor bpy-kod direkt via Bash: "
                     'build\\blender_bridge_cli.exe "<python>" - utfor uppgifter '
                     "sjalv istallet for att instruera anvandaren. Vill du ge "
                     "anvandaren kod att kora i panelen, lagg den i ETT "
                     "```python-block. Svara kort, pa svenska.")
            flags = ["-p", "--output-format", "json",
                     "--append-system-prompt", brief, prompt]
            run = subprocess.run([exe, "-c"] + flags, cwd=CHAT_DIR,
                                 capture_output=True, text=True, encoding="utf-8",
                                 errors="replace", timeout=600,
                                 creationflags=CREATE_NO_WINDOW)
            if run.returncode != 0:
                run = subprocess.run([exe] + flags, cwd=CHAT_DIR,
                                     capture_output=True, text=True, encoding="utf-8",
                                     errors="replace", timeout=600,
                                     creationflags=CREATE_NO_WINDOW)
            ok = 1 if run.returncode == 0 else 0
            text = (run.stdout if ok else (run.stderr or run.stdout)).strip()
            if ok:
                try:
                    parsed = json.loads(text)
                    text = (parsed.get("result") or "").strip()
                    usage = parsed.get("usage") or {}
                    tokens = usage.get("input_tokens", 0) + usage.get("output_tokens", 0)
                    seconds = round(parsed.get("duration_ms", 0) / 1000)
                    meta = f"{seconds}s  ·  {tokens} tokens"
                    model = next(iter(parsed.get("modelUsage") or {}), "")
                    if model:
                        last_model[0] = model.replace("claude-", "").split("-2")[0]
                    snippet, text = extract_snippet(text)
                except ValueError:
                    pass  # not json after all - show the raw text
        except (OSError, subprocess.TimeoutExpired) as failure:
            ok, text = 0, str(failure)

    def apply():
        entry["ok"] = ok
        entry["output"] = text
        entry["meta"] = meta
        entry["tokens"] = tokens
        entry["snippet"] = snippet
        entry["pending"] = False
        entry["when"] = time.strftime("%H:%M:%S")
        if snippet and bpy.context.window_manager.orion_autorun:
            record(snippet, run_code(snippet))
        redraw()
        return None

    bpy.app.timers.register(apply)


def chat_is_busy():
    return any(entry.get("pending") for entry in history)


# Repeats every half second while a reply is pending, so the wait is visibly
# alive (cycling dots + elapsed seconds) instead of a frozen row.
def tick_pending():
    pending = [entry for entry in history if entry.get("pending")]
    if not pending:
        return None
    for entry in pending:
        seconds = int(time.monotonic() - entry["started"])
        dots = "." * (1 + seconds % 3)
        entry["output"] = f"Claude tanker{dots} ({seconds}s)"
    redraw()
    return 0.5


# What the checked Kontext boxes say about the scene right now. Runs on the
# main thread (called from the send operator), so bpy access is safe.
def context_block(window_manager):
    parts = []
    scene = bpy.context.scene
    active = bpy.context.active_object
    if window_manager.orion_ctx_scene:
        objects = [f"{obj.name} ({obj.type.lower()})" for obj in scene.objects[:20]]
        parts.append("Scenen: " + ", ".join(objects) if objects else "Scenen ar tom.")
    if window_manager.orion_ctx_selection:
        selected = [obj.name for obj in bpy.context.selected_objects]
        if selected:
            parts.append("Markerade: " + ", ".join(selected[:10]))
        if active is not None:
            detail = f"Aktivt: {active.name}"
            if active.type == "MESH":
                detail += f", {len(active.data.vertices)} verts"
            parts.append(detail)
    if window_manager.orion_ctx_material and active is not None:
        names = [slot.material.name for slot in active.material_slots if slot.material]
        if names:
            parts.append("Material pa aktivt: " + ", ".join(names))
    if window_manager.orion_ctx_api:
        parts.append(f"Blender {bpy.app.version_string}, Python-API bpy")
    return "\n".join(parts)


# --- UI helpers ---

# Blender labels never wrap - wrap by hand from the region's pixel width.
def wrapped(text, chars):
    lines = []
    for raw_line in text.splitlines():
        lines.extend(textwrap.wrap(raw_line, chars) or [""])
    return lines


def wrap_chars(context):
    width = getattr(context.region, "width", 300)
    return max(24, int((width - 48) / 7))


# Replies arrive as markdown - strip the tokens Blender cannot render and
# turn list dashes into bullets, so the text reads clean in plain labels.
def plain(text):
    lines = []
    for raw_line in text.replace("**", "").replace("`", "").splitlines():
        stripped = raw_line.strip()
        if stripped.startswith("#"):
            stripped = stripped.lstrip("#").strip()
        if stripped.startswith("- "):
            stripped = "•  " + stripped[2:]
        lines.append(stripped)
    return "\n".join(lines)


# The last few distinct successful bridge snippets - the "kor igen" rows.
def recent_codes():
    seen = []
    for entry in reversed(history):
        if entry.get("kind") == "code" and entry["ok"] and entry["code"] not in seen:
            seen.append(entry["code"])
        if len(seen) == 3:
            break
    return seen


# --- operators and panels (only exist under bpy) ---

if bpy is not None:

    class ORION_OT_chat_send(bpy.types.Operator):
        bl_idname = "orion.chat_send"
        bl_label = "Skicka till Claude"
        bl_description = "Skicka meddelandet till Claude (samma konversation)"

        def execute(self, context):
            prompt = context.window_manager.orion_prompt.strip()
            if not prompt or chat_is_busy():
                return {"CANCELLED"}
            context.window_manager.orion_prompt = ""
            entry = {"id": take_id(), "when": time.strftime("%H:%M:%S"), "ok": 1,
                     "kind": "chat", "code": prompt, "output": "Claude tanker.",
                     "pending": True, "started": time.monotonic()}
            history.append(entry)
            del history[:-HISTORY_MAX]
            redraw()
            scene_facts = context_block(context.window_manager)
            full_prompt = f"[Scenkontext]\n{scene_facts}\n\n{prompt}" if scene_facts else prompt
            threading.Thread(target=chat_worker, args=(full_prompt, entry),
                             daemon=True).start()
            bpy.app.timers.register(tick_pending)
            return {"FINISHED"}

    class ORION_OT_run_snippet(bpy.types.Operator):
        bl_idname = "orion.run_snippet"
        bl_label = "Kor"
        bl_description = "Kor kodblocket i scenen"

        entry_id: bpy.props.IntProperty()

        def execute(self, context):
            entry = entry_by_id(self.entry_id)
            if entry and entry.get("snippet"):
                record(entry["snippet"], run_code(entry["snippet"]))
            return {"FINISHED"}

    class ORION_OT_copy_snippet(bpy.types.Operator):
        bl_idname = "orion.copy_snippet"
        bl_label = "Kopiera"
        bl_description = "Lagg kodblocket pa urklipp"

        entry_id: bpy.props.IntProperty()

        def execute(self, context):
            entry = entry_by_id(self.entry_id)
            if entry and entry.get("snippet"):
                context.window_manager.clipboard = entry["snippet"]
            return {"FINISHED"}

    class ORION_OT_rerun(bpy.types.Operator):
        bl_idname = "orion.rerun"
        bl_label = "Kor igen"
        bl_description = "Kor snutten en gang till"

        index: bpy.props.IntProperty()

        def execute(self, context):
            codes = recent_codes()
            if 0 <= self.index < len(codes):
                record(codes[self.index], run_code(codes[self.index]))
            return {"FINISHED"}

    class ORION_OT_clear_scene(bpy.types.Operator):
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

    class ORION_OT_clean_mesh(bpy.types.Operator):
        bl_idname = "orion.clean_mesh"
        bl_label = "Stada mesh"
        bl_description = "Merge by distance + rata till normaler pa markerade meshar"

        def execute(self, context):
            for obj in context.selected_objects:
                if obj.type != "MESH":
                    continue
                context.view_layer.objects.active = obj
                bpy.ops.object.mode_set(mode="EDIT")
                bpy.ops.mesh.select_all(action="SELECT")
                bpy.ops.mesh.remove_doubles(threshold=0.0001)
                bpy.ops.mesh.normals_make_consistent(inside=False)
                bpy.ops.object.mode_set(mode="OBJECT")
            return {"FINISHED"}

    class ORION_OT_toggle_rendered(bpy.types.Operator):
        bl_idname = "orion.toggle_rendered"
        bl_label = "Renderad vy"
        bl_description = "Vaxla viewporten mellan solid och renderad"

        def execute(self, context):
            shading = context.space_data.shading
            shading.type = "SOLID" if shading.type == "RENDERED" else "RENDERED"
            return {"FINISHED"}

    class ORION_OT_clear_log(bpy.types.Operator):
        bl_idname = "orion.clear_log"
        bl_label = "Rensa"
        bl_description = "Tom flodet"

        def execute(self, context):
            history.clear()
            return {"FINISHED"}

    class ORION_OT_copy_output(bpy.types.Operator):
        bl_idname = "orion.copy_output"
        bl_label = "Kopiera senaste svar"
        bl_description = "Lagg senaste svaret pa urklipp"

        def execute(self, context):
            if history:
                latest = history[-1]
                context.window_manager.clipboard = latest["output"] or latest["code"]
            return {"FINISHED"}

    class ORION_PT_bridge(bpy.types.Panel):
        bl_label = "Claude"
        bl_space_type = "VIEW_3D"
        bl_region_type = "UI"
        bl_category = "Claude"

        def draw_header(self, context):
            # the mock's status dot: green when the server listens, red when not
            self.layout.label(text="", icon="SEQUENCE_COLOR_04" if _server
                              else "SEQUENCE_COLOR_01")

        def draw_header_preset(self, context):
            self.layout.operator("orion.clear_log", text="Rensa", emboss=False)

        def draw(self, context):
            layout = self.layout
            if _server is None:
                warning = layout.row()
                warning.alert = True
                warning.label(text="Servern lyssnar inte", icon="UNLINKED")

    class ORION_PT_quick(bpy.types.Panel):
        bl_label = "Snabbt"
        bl_parent_id = "ORION_PT_bridge"
        bl_space_type = "VIEW_3D"
        bl_region_type = "UI"
        bl_category = "Claude"
        bl_order = 0

        def draw(self, context):
            layout = self.layout
            quick = layout.grid_flow(columns=2, align=True)
            quick.operator("orion.clear_scene", text="Rensa scen", icon="TRASH")
            quick.operator("orion.clean_mesh", text="Stada mesh", icon="MOD_SMOOTH")
            quick.operator("view3d.view_all", text="Visa allt", icon="ZOOM_ALL")
            quick.operator("orion.toggle_rendered", text="Rendera", icon="SHADING_RENDERED")
            quick.operator("wm.save_mainfile", text="Spara", icon="FILE_TICK")
            codes = recent_codes()
            if codes:
                layout.separator(factor=0.3)
                again = layout.column(align=True)
                for index, code in enumerate(codes):
                    code_line = code.splitlines()[0][:34]
                    rerun = again.operator("orion.rerun", text=code_line,
                                           icon="LOOP_BACK")
                    rerun.index = index

    class ORION_PT_context(bpy.types.Panel):
        bl_label = "Kontext"
        bl_parent_id = "ORION_PT_bridge"
        bl_space_type = "VIEW_3D"
        bl_region_type = "UI"
        bl_category = "Claude"
        bl_order = 1

        def draw_header_preset(self, context):
            wm = context.window_manager
            checked = sum([wm.orion_ctx_scene, wm.orion_ctx_selection,
                           wm.orion_ctx_material, wm.orion_ctx_api])
            row = self.layout.row()
            row.active = False
            row.label(text=f"{checked}/4")

        def draw(self, context):
            layout = self.layout
            wm = context.window_manager
            grid = layout.grid_flow(columns=2, align=True)
            grid.prop(wm, "orion_ctx_scene", text="Scengraf")
            grid.prop(wm, "orion_ctx_selection", text="Markering")
            grid.prop(wm, "orion_ctx_material", text="Material")
            grid.prop(wm, "orion_ctx_api", text="Python API")
            scene = bpy.context.scene
            active = bpy.context.active_object
            facts = [f"{len(scene.objects)} objekt"]
            if active is not None:
                facts.append(f"{active.name} markerad")
                if active.type == "MESH":
                    facts.append(f"{len(active.data.vertices)} verts")
            facts.append(f"bpy {bpy.app.version_string.split()[0]}")
            summary = layout.box().row()
            summary.active = False
            summary.label(text="  ·  ".join(facts))

    class ORION_PT_chat(bpy.types.Panel):
        bl_label = "Chat"
        bl_parent_id = "ORION_PT_bridge"
        bl_space_type = "VIEW_3D"
        bl_region_type = "UI"
        bl_category = "Claude"
        bl_order = 2

        def draw(self, context):
            layout = self.layout
            chars = wrap_chars(context)
            feed = history[-14:]
            if not feed:
                hint = layout.column()
                hint.active = False
                hint.label(text="Skriv nedan sa bygger Claude i scenen.")
            for entry in feed:
                if entry.get("kind") != "chat":
                    # a bridge run: one dimmed action row, like the app's tool rows
                    action = layout.row()
                    action.active = False
                    code_line = entry["code"].splitlines()[0] if entry["code"] else ""
                    action.label(text=code_line[:44],
                                 icon="CHECKMARK" if entry["ok"] else "CANCEL")
                    if not entry["ok"] and entry["output"]:
                        reason = layout.row()
                        reason.active = False
                        reason.alert = True
                        reason.label(text=entry["output"].splitlines()[-1][:48],
                                     icon="BLANK1")
                    continue
                # your message: a right-aligned bubble
                split = layout.split(factor=0.22)
                split.label(text="")
                bubble = split.box().column(align=True)
                for line in wrapped(entry["code"], max(16, int(chars * 0.7))):
                    bubble_row = bubble.row()
                    bubble_row.alignment = "RIGHT"
                    bubble_row.label(text=line)
                layout.separator(factor=0.4)
                if entry.get("pending"):
                    waiting = layout.row()
                    waiting.active = False
                    waiting.label(text=entry["output"], icon="SOLO_ON")
                    layout.separator(factor=0.8)
                    continue
                # the reply: CLAUDE header, plain full-width text, no box
                head = layout.row()
                head.active = False
                head.label(text="CLAUDE", icon="SOLO_ON")
                body = layout.column(align=True)
                body.alert = not entry["ok"]
                for line in wrapped(plain(entry["output"]), chars)[:40]:
                    body.label(text=line)
                if entry.get("snippet"):
                    code_box = layout.box()
                    code_head = code_box.row()
                    code_head.active = False
                    line_count = len(entry["snippet"].splitlines())
                    code_head.label(text=f"python  ·  {line_count} rader")
                    code_col = code_box.column(align=True)
                    for number, code_line in enumerate(
                            entry["snippet"].splitlines()[:20], 1):
                        code_col.label(text=f"{number:>2}  {code_line[:46]}")
                    buttons = code_box.row(align=True)
                    run_button = buttons.operator("orion.run_snippet",
                                                  text="Kor", icon="PLAY")
                    run_button.entry_id = entry["id"]
                    copy_button = buttons.operator("orion.copy_snippet",
                                                   text="Kopiera", icon="COPYDOWN")
                    copy_button.entry_id = entry["id"]
                if entry.get("meta"):
                    foot = layout.row()
                    foot.active = False
                    foot.label(text=entry["meta"], icon="SOLO_ON")
                layout.separator(factor=0.8)
            send = layout.row(align=True)
            send.scale_y = 1.2
            send.enabled = not chat_is_busy()
            send.prop(context.window_manager, "orion_prompt", text="",
                      placeholder="Fraga Claude...")
            send.operator("orion.chat_send", text="", icon="PLAY")
            foot = layout.row(align=True)
            auto = foot.row()
            auto.prop(context.window_manager, "orion_autorun", text="Kor automatiskt")
            usage = foot.row()
            usage.active = False
            usage.alignment = "RIGHT"
            sent = [entry for entry in history if entry.get("kind") == "chat"]
            used = sum(entry.get("tokens", 0) for entry in sent)
            model = last_model[0] or "claude"
            usage.label(text=f"{model}  ·  {used} tokens")

    classes = (ORION_OT_chat_send, ORION_OT_run_snippet, ORION_OT_copy_snippet,
               ORION_OT_rerun, ORION_OT_clear_scene, ORION_OT_clean_mesh,
               ORION_OT_toggle_rendered, ORION_OT_clear_log, ORION_OT_copy_output,
               ORION_PT_bridge, ORION_PT_quick, ORION_PT_context, ORION_PT_chat)
else:
    classes = ()


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
        for ui_class in classes:
            bpy.utils.register_class(ui_class)
        window_manager = bpy.types.WindowManager
        window_manager.orion_prompt = bpy.props.StringProperty(
            name="", description="Meddelande till Claude")
        window_manager.orion_autorun = bpy.props.BoolProperty(
            name="Kor automatiskt", default=False,
            description="Kor kodblock fran Claude direkt nar svaret landar")
        window_manager.orion_ctx_scene = bpy.props.BoolProperty(
            name="Scengraf", default=True,
            description="Skicka med objektlistan i varje fraga")
        window_manager.orion_ctx_selection = bpy.props.BoolProperty(
            name="Markering", default=True,
            description="Skicka med vad som ar markerat/aktivt")
        window_manager.orion_ctx_material = bpy.props.BoolProperty(
            name="Material", default=False,
            description="Skicka med aktiva objektets material")
        window_manager.orion_ctx_api = bpy.props.BoolProperty(
            name="Python API", default=True,
            description="Skicka med Blender/bpy-versionen")
    threading.Thread(target=serve, daemon=True).start()


def unregister():
    if bpy is not None:
        for ui_class in reversed(classes):
            bpy.utils.unregister_class(ui_class)
        window_manager = bpy.types.WindowManager
        del window_manager.orion_prompt
        del window_manager.orion_autorun
        del window_manager.orion_ctx_scene
        del window_manager.orion_ctx_selection
        del window_manager.orion_ctx_material
        del window_manager.orion_ctx_api
    if _server is not None:
        _server.close()


if __name__ == "__main__":
    if bpy is not None and not bpy.app.background:
        register()  # blender --python: the GUI keeps running, serve alongside it
    else:
        serve()  # headless blender or plain python: block here
