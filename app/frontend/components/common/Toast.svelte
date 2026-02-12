<script>
  import { page } from "@inertiajs/svelte";
  import { toasts } from "$lib/stores.js";

  let flash = $derived($page?.props?.flash || {});

  // flash 메시지를 토스트로 변환
  $effect(() => {
    if (flash.success) toasts.add(flash.success, "success");
    if (flash.error) toasts.add(flash.error, "error");
    if (flash.notice) toasts.add(flash.notice, "info");
  });

  const icons = {
    success: "✅",
    error: "❌",
    info: "ℹ️",
    warning: "⚠️",
  };

  const bgColors = {
    success: "bg-teal-50 border-teal-200 text-teal-800",
    error: "bg-rose-50 border-rose-200 text-rose-800",
    info: "bg-sky-50 border-sky-200 text-sky-800",
    warning: "bg-amber-50 border-amber-200 text-amber-800",
  };
</script>

{#if $toasts.length > 0}
  <div class="fixed right-4 top-4 z-[100] flex flex-col gap-2">
    {#each $toasts as toast (toast.id)}
      <div
        class="flex items-center gap-3 rounded-xl border px-4 py-3 shadow-lg transition-all duration-300 {bgColors[toast.type] || bgColors.info}"
      >
        <span>{icons[toast.type] || icons.info}</span>
        <p class="text-sm font-medium">{toast.message}</p>
        <button
          onclick={() => toasts.remove(toast.id)}
          class="ml-2 text-current opacity-50 hover:opacity-100"
        >
          ✕
        </button>
      </div>
    {/each}
  </div>
{/if}
