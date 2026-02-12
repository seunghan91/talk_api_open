<script>
  import AppShell from "$components/layout/AppShell.svelte";
  import Card from "$components/common/Card.svelte";
  import Button from "$components/common/Button.svelte";
  import Avatar from "$components/common/Avatar.svelte";
  import EmptyState from "$components/common/EmptyState.svelte";
  import VoicePlayer from "$components/voice/VoicePlayer.svelte";
  import { timeAgo } from "$lib/utils.js";

  let { broadcasts = [], pagination = {} } = $props();
</script>

<AppShell>
  <div class="mb-6 flex items-center justify-between">
    <h1 class="text-2xl font-bold text-slate-900">📢 브로드캐스트</h1>
    <Button href="/broadcasts/new" variant="primary" size="md">+ 새 방송</Button>
  </div>

  {#if broadcasts.length === 0}
    <EmptyState
      icon="📢"
      title="브로드캐스트가 없어요"
      description="첫 번째 음성 메시지를 보내보세요!"
    >
      <Button href="/broadcasts/new" variant="primary">녹음 시작</Button>
    </EmptyState>
  {:else}
    <div class="space-y-3">
      {#each broadcasts.filter(Boolean) as broadcast (broadcast.id)}
        <a href="/broadcasts/{broadcast.id}" class="block">
          <Card hover>
            <div class="flex items-start gap-3">
              <Avatar userId={broadcast.user?.id} nickname={broadcast.user?.nickname} />
              <div class="flex-1">
                <div class="flex items-center gap-2">
                  <span class="font-medium text-slate-900">{broadcast.user?.nickname}</span>
                  <span class="text-xs text-slate-400">{timeAgo(broadcast.created_at)}</span>
                </div>
                {#if broadcast.audio_url}
                  <div class="mt-2">
                    <VoicePlayer src={broadcast.audio_url} duration={broadcast.duration} />
                  </div>
                {/if}
              </div>
            </div>
          </Card>
        </a>
      {/each}
    </div>
  {/if}
</AppShell>
