<script>
  import { formatDuration } from "$lib/utils.js";

  let {
    src = "",
    duration = 0,
    compact = false,
    light = false,
  } = $props();

  let audio = $state(null);
  let isPlaying = $state(false);
  let currentTime = $state(0);
  let progressPercent = $state(0);

  function togglePlay() {
    if (!audio) {
      audio = new Audio(src);
      audio.addEventListener("timeupdate", () => {
        currentTime = audio.currentTime;
        progressPercent = duration > 0 ? (currentTime / duration) * 100 : 0;
      });
      audio.addEventListener("ended", () => {
        isPlaying = false;
        currentTime = 0;
        progressPercent = 0;
      });
    }

    if (isPlaying) {
      audio.pause();
    } else {
      audio.play();
    }
    isPlaying = !isPlaying;
  }

  let displayDuration = $derived(
    isPlaying ? formatDuration(currentTime) : formatDuration(duration)
  );

  let textColor = $derived(light ? "text-white/80" : "text-slate-500");
  let barBg = $derived(light ? "bg-white/30" : "bg-slate-200");
  let barFill = $derived(light ? "bg-white" : "bg-sky-500");
  let btnColor = $derived(light ? "text-white" : "text-sky-600");
</script>

<div class="flex items-center gap-3 {compact ? '' : 'rounded-xl bg-slate-50 px-3 py-2'}">
  <!-- 재생/일시정지 버튼 -->
  <button onclick={togglePlay} class="flex-shrink-0 text-xl {btnColor}">
    {isPlaying ? "⏸" : "▶"}
  </button>

  <!-- 프로그레스 바 -->
  <div class="flex-1">
    <div class="h-1.5 rounded-full {barBg}">
      <div
        class="h-full rounded-full transition-all duration-200 {barFill}"
        style="width: {progressPercent}%"
      ></div>
    </div>
  </div>

  <!-- 시간 -->
  <span class="flex-shrink-0 text-xs font-medium {textColor}">
    {displayDuration}
  </span>
</div>
