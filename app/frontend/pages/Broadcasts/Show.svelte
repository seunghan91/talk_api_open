<script>
  import AppShell from "$components/layout/AppShell.svelte";
  import Card from "$components/common/Card.svelte";
  import Button from "$components/common/Button.svelte";
  import Avatar from "$components/common/Avatar.svelte";
  import VoicePlayer from "$components/voice/VoicePlayer.svelte";
  import { timeAgo } from "$lib/utils.js";

  let { broadcast = {} } = $props();
</script>

<AppShell>
  <div class="mb-4">
    <a href="/broadcasts" class="text-sm text-slate-500 hover:text-sky-600">← 브로드캐스트 목록</a>
  </div>

  <Card>
    <div class="flex items-start gap-4">
      <Avatar userId={broadcast.user?.id} nickname={broadcast.user?.nickname} size="lg" />
      <div class="flex-1">
        <div class="flex items-center gap-2">
          <h2 class="text-lg font-semibold text-slate-900">{broadcast.user?.nickname}</h2>
          <span class="text-sm text-slate-400">{timeAgo(broadcast.created_at)}</span>
        </div>

        {#if broadcast.recipients_count}
          <p class="mt-1 text-sm text-slate-500">{broadcast.recipients_count}명에게 전송됨</p>
        {/if}

        {#if broadcast.audio_url}
          <div class="mt-4">
            <VoicePlayer src={broadcast.audio_url} duration={broadcast.duration} />
          </div>
        {/if}

        <div class="mt-6 flex gap-3">
          <Button variant="primary" size="md">💬 답장하기</Button>
          <Button variant="secondary" size="md">🚨 신고</Button>
        </div>
      </div>
    </div>
  </Card>
</AppShell>
