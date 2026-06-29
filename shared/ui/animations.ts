/**
 * SyncBridge animation library — typed presets from shared/theme/animations.json
 */

export type AnimationDuration = "fast" | "normal" | "slow" | "slower";
export type AnimationEasing = "out" | "liquid" | "inOut";

export const AnimationDurations: Record<AnimationDuration, number> = {
  fast: 150,
  normal: 250,
  slow: 350,
  slower: 500,
};

export const AnimationEasings: Record<AnimationEasing, string> = {
  out: "cubic-bezier(0.22, 1, 0.36, 1)",
  liquid: "cubic-bezier(0.34, 1.2, 0.64, 1)",
  inOut: "cubic-bezier(0.45, 0, 0.55, 1)",
};

export type AnimationPreset =
  | "fadeIn"
  | "fadeOut"
  | "slideUp"
  | "slideDown"
  | "scaleIn"
  | "modalEnter"
  | "progressPulse"
  | "successPop"
  | "dockPress"
  | "liquidFloat";

/** CSS class names for web — maps to shared/theme/web/animations.css */
export const WebAnimationClasses: Record<AnimationPreset, string> = {
  fadeIn: "sb-animate-fade-in",
  fadeOut: "sb-animate-fade-out",
  slideUp: "sb-animate-slide-up",
  slideDown: "sb-animate-slide-down",
  scaleIn: "sb-animate-scale-in",
  modalEnter: "sb-animate-modal",
  progressPulse: "sb-animate-progress-pulse",
  successPop: "sb-animate-scale-in",
  dockPress: "sb-transition-fast",
  liquidFloat: "sb-animate-liquid-float",
};

export function durationMs(key: AnimationDuration): number {
  return AnimationDurations[key];
}

export function easingCss(key: AnimationEasing): string {
  return AnimationEasings[key];
}

export function transitionStyle(
  properties: string[],
  duration: AnimationDuration = "normal",
  easing: AnimationEasing = "out",
): string {
  const ms = durationMs(duration);
  const ease = easingCss(easing);
  return properties.map((p) => `${p} ${ms}ms ${ease}`).join(", ");
}
