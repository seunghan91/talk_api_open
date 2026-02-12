<script>
  let {
    icon = "📭",
    title = "아직 아무것도 없어요",
    description = "",
    children,
  } = $props();
</script>

<div class="flex flex-col items-center justify-center py-16 text-center">
  <span class="mb-4 text-5xl">{icon}</span>
  <h3 class="mb-2 text-lg font-semibold text-slate-700">{title}</h3>
  {#if description}
    <p class="mb-6 max-w-sm text-sm text-slate-500">{description}</p>
  {/if}
  {#if children}
    {@render children()}
  {/if}
</div>
