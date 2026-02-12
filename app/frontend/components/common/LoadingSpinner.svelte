<script>
  let {
    size = "md",
    class: className = "",
  } = $props();

  const sizes = {
    sm: "h-4 w-4 border-2",
    md: "h-8 w-8 border-2",
    lg: "h-12 w-12 border-3",
  };
</script>

<div class="flex items-center justify-center {className}">
  <div
    class="animate-spin rounded-full border-sky-500 border-t-transparent {sizes[size] || sizes.md}"
  ></div>
</div>
