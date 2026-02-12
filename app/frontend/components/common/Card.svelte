<script>
  let {
    hover = false,
    padding = true,
    class: className = "",
    children,
    onclick,
  } = $props();

  let classes = $derived(
    `rounded-xl border border-slate-200 bg-white shadow-card ${
      hover ? "transition-shadow duration-150 hover:shadow-card-hover cursor-pointer" : ""
    } ${padding ? "p-4 sm:p-5" : ""} ${className}`
  );
</script>

{#if onclick}
  <button {onclick} class="{classes} w-full text-left">
    {@render children()}
  </button>
{:else}
  <div class={classes}>
    {@render children()}
  </div>
{/if}
