<script>
  import { page } from "@inertiajs/svelte";
  import { NAV_ITEMS } from "$lib/constants.js";

  let currentPath = $derived($page?.url || "/");

  function isActive(href) {
    if (href === "/") return currentPath === "/";
    return currentPath.startsWith(href);
  }

  const iconMap = {
    home: "🏠",
    broadcast: "📢",
    chat: "💬",
    profile: "👤",
    notification: "🔔",
    settings: "⚙️",
  };
</script>

<aside class="flex w-64 flex-col border-r border-slate-200 bg-white">
  <!-- 로고 -->
  <div class="flex h-16 items-center gap-2 border-b border-slate-200 px-6">
    <span class="text-2xl">☁️</span>
    <span class="bg-gradient-to-r from-sky-500 to-cyan-400 bg-clip-text text-xl font-bold text-transparent">
      Talkk
    </span>
  </div>

  <!-- 네비게이션 -->
  <nav class="flex-1 space-y-1 px-3 py-4">
    {#each NAV_ITEMS as item}
      <a
        href={item.href}
        class="flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium transition-all duration-150
          {isActive(item.href)
            ? 'bg-sky-50 text-sky-700'
            : 'text-slate-600 hover:bg-slate-50 hover:text-slate-900'}"
      >
        <span class="text-lg">{iconMap[item.icon] || "📌"}</span>
        <span>{item.label}</span>
      </a>
    {/each}
  </nav>

  <!-- 하단 프로필 -->
  <div class="border-t border-slate-200 p-4">
    <div class="flex items-center gap-3">
      <div class="flex h-9 w-9 items-center justify-center rounded-full bg-sky-100 text-sky-600">
        <span class="text-sm font-semibold">
          {$page?.props?.auth?.user?.nickname?.[0] || "?"}
        </span>
      </div>
      <div class="flex-1 truncate">
        <p class="truncate text-sm font-medium text-slate-900">
          {$page?.props?.auth?.user?.nickname || "게스트"}
        </p>
      </div>
    </div>
  </div>
</aside>
