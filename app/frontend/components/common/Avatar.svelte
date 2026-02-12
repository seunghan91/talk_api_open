<script>
  import { getAnimalEmoji } from "$lib/utils.js";

  let {
    userId = null,
    nickname = "",
    size = "md",
    class: className = "",
  } = $props();

  const sizes = {
    sm: "h-8 w-8 text-sm",
    md: "h-10 w-10 text-lg",
    lg: "h-14 w-14 text-2xl",
    xl: "h-20 w-20 text-3xl",
  };

  let emoji = $derived(getAnimalEmoji(userId));
  let sizeClass = $derived(sizes[size] || sizes.md);
</script>

<div
  class="flex items-center justify-center rounded-full bg-sky-100 {sizeClass} {className}"
  title={nickname}
>
  {emoji}
</div>
