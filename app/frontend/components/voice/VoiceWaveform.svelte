<script>
  let { active = false, barCount = 20 } = $props();

  let bars = $state(Array(barCount).fill(0).map(() => Math.random() * 0.3 + 0.1));
  let animationFrame = $state(null);

  $effect(() => {
    if (active) {
      const animate = () => {
        bars = bars.map(() => Math.random() * 0.8 + 0.2);
        animationFrame = requestAnimationFrame(animate);
      };
      animate();
      return () => {
        if (animationFrame) cancelAnimationFrame(animationFrame);
      };
    } else {
      bars = bars.map(() => Math.random() * 0.3 + 0.1);
    }
  });
</script>

<div class="flex items-end gap-0.5 h-8">
  {#each bars as height, i}
    <div
      class="w-1 rounded-full transition-all duration-100 {active ? 'bg-sky-500' : 'bg-slate-300'}"
      style="height: {height * 100}%"
    ></div>
  {/each}
</div>
