<script>
  let {
    open = false,
    title = "",
    onclose,
    children,
  } = $props();

  function handleBackdropClick(e) {
    if (e.target === e.currentTarget) {
      onclose?.();
    }
  }

  function handleKeydown(e) {
    if (e.key === "Escape") {
      onclose?.();
    }
  }
</script>

<svelte:window onkeydown={handleKeydown} />

{#if open}
  <!-- backdrop -->
  <div
    class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4 backdrop-blur-sm"
    onclick={handleBackdropClick}
    role="dialog"
    aria-modal="true"
  >
    <!-- modal -->
    <div class="w-full max-w-md rounded-2xl bg-white p-6 shadow-xl">
      {#if title}
        <div class="mb-4 flex items-center justify-between">
          <h2 class="text-lg font-semibold text-slate-900">{title}</h2>
          <button
            onclick={onclose}
            class="rounded-lg p-1 text-slate-400 transition-colors hover:bg-slate-100 hover:text-slate-600"
          >
            ✕
          </button>
        </div>
      {/if}
      {@render children()}
    </div>
  </div>
{/if}
