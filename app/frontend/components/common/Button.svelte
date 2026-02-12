<script>
  let {
    variant = "primary",
    size = "md",
    disabled = false,
    loading = false,
    type = "button",
    href = null,
    class: className = "",
    children,
    onclick,
    ...rest
  } = $props();

  const baseClasses = "inline-flex items-center justify-center font-medium transition-all duration-150 focus:outline-none focus:ring-2 focus:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50";

  const variants = {
    primary: "bg-gradient-to-r from-sky-500 to-sky-600 text-white hover:from-sky-600 hover:to-sky-700 focus:ring-sky-500 shadow-sm",
    secondary: "bg-white text-slate-700 border border-slate-200 hover:bg-slate-50 focus:ring-sky-500",
    ghost: "text-slate-600 hover:bg-slate-100 hover:text-slate-900 focus:ring-sky-500",
    danger: "bg-rose-500 text-white hover:bg-rose-600 focus:ring-rose-500",
  };

  const sizes = {
    sm: "text-sm px-3 py-1.5 rounded-md gap-1.5",
    md: "text-sm px-4 py-2.5 rounded-lg gap-2",
    lg: "text-base px-6 py-3 rounded-lg gap-2",
    xl: "text-lg px-8 py-4 rounded-xl gap-2.5",
  };

  let classes = $derived(
    `${baseClasses} ${variants[variant] || variants.primary} ${sizes[size] || sizes.md} ${className}`
  );
</script>

{#if href}
  <a {href} class={classes} {...rest}>
    {#if loading}
      <span class="h-4 w-4 animate-spin rounded-full border-2 border-current border-t-transparent"></span>
    {/if}
    {@render children()}
  </a>
{:else}
  <button {type} {onclick} class={classes} disabled={disabled || loading} {...rest}>
    {#if loading}
      <span class="h-4 w-4 animate-spin rounded-full border-2 border-current border-t-transparent"></span>
    {/if}
    {@render children()}
  </button>
{/if}
