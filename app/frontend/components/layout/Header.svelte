<script>
  import { page } from "@inertiajs/svelte";
  import { theme } from "$lib/stores.js";

  let user = $derived($page?.props?.auth?.user);
  let unreadCount = $state(0);
</script>

<header class="flex h-16 items-center justify-between border-b border-slate-200 bg-white px-4 sm:px-6">
  <!-- 좌측: 로고 (모바일) -->
  <div class="flex items-center gap-2 md:hidden">
    <span class="text-xl">☁️</span>
    <span class="bg-gradient-to-r from-sky-500 to-cyan-400 bg-clip-text text-lg font-bold text-transparent">
      Talkk
    </span>
  </div>

  <!-- 중앙: 빈 공간 또는 검색 (향후) -->
  <div class="hidden flex-1 md:block"></div>

  <!-- 우측: 알림 + 설정 -->
  <div class="flex items-center gap-3">
    <!-- 알림 -->
    <a href="/notifications" class="relative rounded-lg p-2 text-slate-500 transition-colors hover:bg-slate-100 hover:text-slate-700">
      <span class="text-xl">🔔</span>
      {#if unreadCount > 0}
        <span class="absolute -right-0.5 -top-0.5 flex h-5 w-5 items-center justify-center rounded-full bg-rose-500 text-[10px] font-bold text-white">
          {unreadCount > 9 ? "9+" : unreadCount}
        </span>
      {/if}
    </a>

    <!-- 테마 토글 -->
    <button
      onclick={() => theme.toggle()}
      class="rounded-lg p-2 text-slate-500 transition-colors hover:bg-slate-100 hover:text-slate-700"
    >
      <span class="text-xl">{$theme === "dark" ? "☀️" : "🌙"}</span>
    </button>

    <!-- 설정 -->
    <a href="/settings" class="rounded-lg p-2 text-slate-500 transition-colors hover:bg-slate-100 hover:text-slate-700">
      <span class="text-xl">⚙️</span>
    </a>
  </div>
</header>
