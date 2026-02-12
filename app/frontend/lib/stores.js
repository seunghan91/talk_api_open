import { writable, derived } from "svelte/store";

// 테마 스토어 (light / dark)
function createThemeStore() {
  const stored = typeof localStorage !== "undefined"
    ? localStorage.getItem("talkk-theme")
    : null;
  const initial = stored || "light";
  const { subscribe, set, update } = writable(initial);

  return {
    subscribe,
    toggle: () => update((current) => {
      const next = current === "light" ? "dark" : "light";
      if (typeof localStorage !== "undefined") {
        localStorage.setItem("talkk-theme", next);
      }
      if (typeof document !== "undefined") {
        document.documentElement.classList.toggle("dark", next === "dark");
      }
      return next;
    }),
    set: (value) => {
      if (typeof localStorage !== "undefined") {
        localStorage.setItem("talkk-theme", value);
      }
      if (typeof document !== "undefined") {
        document.documentElement.classList.toggle("dark", value === "dark");
      }
      set(value);
    },
  };
}

export const theme = createThemeStore();

// 사이드바 열림/닫힘 상태
export const sidebarOpen = writable(false);

// 모바일 감지
export const isMobile = writable(false);

// 토스트 알림 스토어
function createToastStore() {
  const { subscribe, update } = writable([]);

  const api = {
    subscribe,
    add: (message, type = "info", duration = 3000) => {
      const id = Date.now();
      update((toasts) => [...toasts, { id, message, type, duration }]);
      setTimeout(() => {
        update((toasts) => toasts.filter((t) => t.id !== id));
      }, duration);
    },
    remove: (id) => {
      update((toasts) => toasts.filter((t) => t.id !== id));
    },
  };

  api.success = (message, duration = 3000) => api.add(message, "success", duration);
  api.error = (message, duration = 3000) => api.add(message, "error", duration);

  return api;
}

export const toasts = createToastStore();
