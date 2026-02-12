<script>
  import { router } from "@inertiajs/svelte";
  import AppShell from "$components/layout/AppShell.svelte";
  import Card from "$components/common/Card.svelte";
  import Button from "$components/common/Button.svelte";
  import VoiceRecorder from "$components/voice/VoiceRecorder.svelte";

  let audioBlob = $state(null);
  let duration = $state(0);
  let loading = $state(false);

  function handleRecordingComplete(blob, dur) {
    audioBlob = blob;
    duration = dur;
  }

  function handleSubmit() {
    if (!audioBlob) return;

    loading = true;
    const formData = new FormData();
    formData.append("audio", audioBlob, "broadcast.webm");
    formData.append("duration", Math.round(duration));

    router.post("/broadcasts", formData, {
      forceFormData: true,
      onFinish: () => { loading = false; },
    });
  }
</script>

<AppShell>
  <div class="mb-4">
    <a href="/broadcasts" class="text-sm text-slate-500 hover:text-sky-600">← 뒤로</a>
  </div>

  <div class="mx-auto max-w-md">
    <div class="mb-6 text-center">
      <h1 class="text-2xl font-bold text-slate-900">새 브로드캐스트</h1>
      <p class="mt-1 text-sm text-slate-500">최대 60초의 음성 메시지를 녹음하세요</p>
    </div>

    <Card class="text-center">
      <VoiceRecorder onComplete={handleRecordingComplete} />

      {#if audioBlob}
        <div class="mt-6">
          <Button onclick={handleSubmit} variant="primary" size="xl" {loading} class="w-full">
            {loading ? "전송 중..." : "📢 브로드캐스트 전송"}
          </Button>
        </div>
      {/if}
    </Card>
  </div>
</AppShell>
