# MkAssistant Roadmap

## Milestone 1 — Voice prototype
1. Build/install on target iPhone (iOS 15.6.1).
2. Validate microphone and Arabic/Iraqi speech recognition.
3. Replace placeholder wake-word engine with on-device detection for “Hey MK”.
4. Validate foreground, locked-screen, background and CarPlay-connected behavior.
5. Add streaming AI provider behind AssistantAgent.
6. Add TTS, interruption and follow-up window.

## Milestone 2 — CarPlay
Reuse only proven concepts from the existing project; do not modify MkCar.
Validate scene lifecycle and audio routing on the real vehicle before adding UI complexity.

## Milestone 3 — Tools
Navigation, location, weather, places, media and current-trip context.

## Milestone 4 — Vehicle
Read-only OBD-II telemetry and DTC explanation.

## Safety
Vehicle-control integrations remain read-only unless a separately reviewed safe capability is introduced.
Secrets are never committed to Git.

<!-- build trigger: phase-1 -->

<!-- rebuild: voice-loop-fix-2 -->
