<script>
  let {
    variant = "default",
    children,
    class: className = "",
  } = $props();

  const variants = {
    default: "bg-slate-100 text-slate-700",
    primary: "bg-sky-100 text-sky-700",
    success: "bg-teal-100 text-teal-700",
    warning: "bg-amber-100 text-amber-700",
    danger: "bg-rose-100 text-rose-700",
    online: "bg-cyan-400 text-white",
  };

  let classes = $derived(
    `inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium ${variants[variant] || variants.default} ${className}`
  );
</script>

<span class={classes}>
  {@render children()}
</span>
