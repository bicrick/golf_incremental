extends RefCounted
## Resumes the Godot web AudioContext on first pointer/key (autoplay unlock).

const _INSTALL_JS := """
(function () {
  if (window.__golfAudioUnlockInstalled) {
    return;
  }
  window.__golfAudioUnlockInstalled = true;
  var contexts = [];
  function remember(ctx) {
    if (ctx && contexts.indexOf(ctx) < 0) {
      contexts.push(ctx);
    }
  }
  function wrap(proto, name) {
    if (!proto || typeof proto[name] !== "function") {
      return;
    }
    var orig = proto[name];
    proto[name] = function () {
      remember(this.context || this);
      return orig.apply(this, arguments);
    };
  }
  if (window.AudioContext) {
    wrap(AudioContext.prototype, "resume");
    wrap(AudioContext.prototype, "createGain");
  }
  if (window.AudioBufferSourceNode) {
    wrap(AudioBufferSourceNode.prototype, "start");
  }
  window.__golfResumeAudio = function () {
    if (window.__golfAudioCtx && window.__golfAudioCtx.resume) {
      remember(window.__golfAudioCtx);
    }
    for (var i = 0; i < contexts.length; i++) {
      var ctx = contexts[i];
      if (ctx && ctx.state && ctx.state !== "running" && ctx.resume) {
        ctx.resume();
      }
    }
    return contexts.length;
  };
  ["pointerdown", "touchstart", "keydown", "mousedown"].forEach(function (type) {
    window.addEventListener(type, window.__golfResumeAudio, { capture: true, passive: true });
  });
})();
"""

const _RESUME_JS := "typeof window.__golfResumeAudio === 'function' && window.__golfResumeAudio();"


static func install() -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval(_INSTALL_JS, true)


static func resume() -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval(_RESUME_JS, true)


static func is_unlock_gesture(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).pressed
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	if event is InputEventKey:
		var key := event as InputEventKey
		return key.pressed and not key.echo
	return false
