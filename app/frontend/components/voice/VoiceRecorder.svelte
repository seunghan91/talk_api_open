<script>
  import { MAX_RECORDING_DURATION } from "$lib/constants.js";
  import { formatDuration } from "$lib/utils.js";

  let { onComplete, maxDuration = MAX_RECORDING_DURATION } = $props();

  let isRecording = $state(false);
  let elapsed = $state(0);
  let mediaRecorder = $state(null);
  let chunks = $state([]);
  let timer = $state(null);
  let audioBlob = $state(null);
  let audioUrl = $state(null);

  async function startRecording() {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      mediaRecorder = new MediaRecorder(stream, { mimeType: "audio/webm;codecs=opus" });
      chunks = [];

      mediaRecorder.ondataavailable = (e) => {
        if (e.data.size > 0) chunks.push(e.data);
      };

      mediaRecorder.onstop = () => {
        const blob = new Blob(chunks, { type: "audio/webm" });
        audioBlob = blob;
        audioUrl = URL.createObjectURL(blob);
        stream.getTracks().forEach((t) => t.stop());
        onComplete?.(blob, elapsed);
      };

      mediaRecorder.start(100);
      isRecording = true;
      elapsed = 0;

      timer = setInterval(() => {
        elapsed += 1;
        if (elapsed >= maxDuration) {
          stopRecording();
        }
      }, 1000);
    } catch (err) {
      console.error("마이크 접근 실패:", err);
    }
  }

  function stopRecording() {
    if (mediaRecorder && mediaRecorder.state !== "inactive") {
      mediaRecorder.stop();
    }
    isRecording = false;
    if (timer) {
      clearInterval(timer);
      timer = null;
    }
  }

  function resetRecording() {
    audioBlob = null;
    audioUrl = null;
    elapsed = 0;
  }

  let progress = $derived((elapsed / maxDuration) * 100);
</script>

<div class="flex flex-col items-center gap-6 py-6">
  <!-- 타이머 표시 -->
  <div class="relative">
    <svg class="h-32 w-32" viewBox="0 0 120 120">
      <!-- 배경 원 -->
      <circle cx="60" cy="60" r="54" fill="none" stroke="#E2E8F0" stroke-width="6" />
      <!-- 진행 원 -->
      <circle
        cx="60" cy="60" r="54"
        fill="none"
        stroke={isRecording ? "#0EA5E9" : "#94A3B8"}
        stroke-width="6"
        stroke-dasharray={2 * Math.PI * 54}
        stroke-dashoffset={2 * Math.PI * 54 * (1 - progress / 100)}
        stroke-linecap="round"
        transform="rotate(-90, 60, 60)"
        class="transition-all duration-1000"
      />
    </svg>
    <div class="absolute inset-0 flex flex-col items-center justify-center">
      <span class="text-2xl font-bold text-slate-900">{formatDuration(elapsed)}</span>
      <span class="text-xs text-slate-400">/ {formatDuration(maxDuration)}</span>
    </div>
  </div>

  <!-- 녹음 버튼 -->
  {#if audioBlob}
    <div class="flex gap-3">
      <button
        onclick={resetRecording}
        aria-label="다시 녹음"
        class="flex h-14 w-14 items-center justify-center rounded-full border-2 border-slate-200 text-xl text-slate-500 transition-colors hover:border-slate-300 hover:text-slate-700"
      >
        🔄
      </button>
      <div class="flex items-center gap-2 rounded-full bg-slate-100 px-4 py-2">
        <span class="text-sm text-teal-600 font-medium">✅ 녹음 완료</span>
      </div>
    </div>
  {:else if isRecording}
    <button
      onclick={stopRecording}
      aria-label="녹음 중지"
      class="flex h-16 w-16 items-center justify-center rounded-full bg-rose-500 text-white shadow-lg shadow-rose-500/30 transition-transform hover:scale-105 active:scale-95"
    >
      <div class="h-5 w-5 rounded-sm bg-white"></div>
    </button>
    <p class="text-sm text-slate-500">녹음 중... 터치하여 중지</p>
  {:else}
    <button
      onclick={startRecording}
      aria-label="녹음 시작"
      class="flex h-16 w-16 items-center justify-center rounded-full bg-gradient-to-r from-sky-500 to-cyan-400 text-2xl text-white shadow-lg shadow-sky-500/30 transition-transform hover:scale-105 active:scale-95"
    >
      🎙️
    </button>
    <p class="text-sm text-slate-500">터치하여 녹음 시작</p>
  {/if}
</div>
