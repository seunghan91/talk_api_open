<script>
  import { page } from "@inertiajs/svelte";

  let currentPath = $derived($page?.url || "/");

  const items = [
    { href: "/", label: "홈", icon: "🏠" },
    { href: "/broadcasts", label: "방송", icon: "📢" },
    { href: "/broadcasts/new", label: "녹음", icon: "🎙️", highlight: true },
    { href: "/conversations", label: "채팅", icon: "💬" },
    { href: "/profile", label: "프로필", icon: "👤" },
  ];

  function isActive(href) {
    if (href === "/") return currentPath === "/";
    return currentPath.startsWith(href);
  }
</script>

<nav class="safe-area-bottom border-t border-slate-200 bg-white">
  <div class="flex items-center justify-around px-2 py-1">
    {#each items as item}
      <a
        href={item.href}
        class="flex flex-col items-center gap-0.5 px-3 py-1.5 text-xs transition-colors
          {item.highlight
            ? 'relative -mt-4'
            : isActive(item.href)
              ? 'text-sky-600'
              : 'text-slate-400 hover:text-slate-600'}"
      >
        {#if item.highlight}
          <div class="flex h-12 w-12 items-center justify-center rounded-full bg-gradient-to-r from-sky-500 to-cyan-400 shadow-lg shadow-sky-500/25">
            <span class="text-xl text-white">{item.icon}</span>
          </div>
          <span class="mt-0.5 text-sky-600">{item.label}</span>
        {:else}
          <span class="text-xl">{item.icon}</span>
          <span>{item.label}</span>
        {/if}
      </a>
    {/each}
  </div>
</nav>

<style>
  .safe-area-bottom {
    padding-bottom: env(safe-area-inset-bottom, 0);
  }
</style>
