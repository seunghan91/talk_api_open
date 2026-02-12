<script>
  import AppShell from "$components/layout/AppShell.svelte";
  import Card from "$components/common/Card.svelte";
  import Button from "$components/common/Button.svelte";
  import Avatar from "$components/common/Avatar.svelte";
  import EmptyState from "$components/common/EmptyState.svelte";
  import VoicePlayer from "$components/voice/VoicePlayer.svelte";
  import { timeAgo, formatDuration } from "$lib/utils.js";

  let { broadcasts = [], pagination = {} } = $props();
</script>

<AppShell>
  <!-- 새 브로드캐스트 생성 CTA -->
  <Card class="mb-6 bg-gradient-to-r from-sky-50 to-cyan-50 border-sky-200">
    <div class="flex items-center gap-4">
      <div class="flex h-12 w-12 items-center justify-center rounded-full bg-gradient-to-r from-sky-500 to-cyan-400 text-2xl text-white shadow-lg shadow-sky-500/25">
        🎙️
      </div>
      <div class="flex-1">
        <h3 class="font-semibold text-slate-900">60초 음성으로 이야기하세요</h3>
        <p class="text-sm text-slate-500">랜덤 사용자에게 음성 메시지를 보내보세요</p>
      </div>
      <Button href="/broadcasts/new" variant="primary" size="md">녹음 시작</Button>
    </div>
  </Card>

  <!-- 브로드캐스트 피드 -->
  <div class="space-y-3">
    <h2 class="text-lg font-semibold text-slate-900">받은 브로드캐스트</h2>

    {#if broadcasts.length === 0}
      <EmptyState
        icon="📢"
        title="아직 받은 브로드캐스트가 없어요"
        description="다른 사람들이 보내는 음성 메시지를 기다려보세요"
      />
    {:else}
      {#each broadcasts.filter(Boolean) as broadcast (broadcast.id)}
        <Card hover>
          <div class="flex items-start gap-3">
            <Avatar userId={broadcast.user?.id} nickname={broadcast.user?.nickname} />
            <div class="flex-1 min-w-0">
              <div class="flex items-center gap-2">
                <span class="font-medium text-slate-900">
                  {broadcast.user?.nickname || "익명 사용자"}
                </span>
                <span class="text-xs text-slate-400">{timeAgo(broadcast.created_at)}</span>
              </div>

              {#if broadcast.audio_url}
                <div class="mt-2">
                  <VoicePlayer
                    src={broadcast.audio_url}
                    duration={broadcast.duration}
                  />
                </div>
              {/if}

              <div class="mt-3 flex items-center gap-3">
                <Button href="/broadcasts/{broadcast.id}" variant="secondary" size="sm">
                  답장하기
                </Button>
              </div>
            </div>
          </div>
        </Card>
      {/each}

      <!-- 페이지네이션 -->
      {#if pagination.total_pages > 1}
        <div class="flex justify-center gap-2 pt-4">
          {#if pagination.current_page > 1}
            <Button href="/?page={pagination.current_page - 1}" variant="ghost" size="sm">← 이전</Button>
          {/if}
          <span class="flex items-center text-sm text-slate-500">
            {pagination.current_page} / {pagination.total_pages}
          </span>
          {#if pagination.current_page < pagination.total_pages}
            <Button href="/?page={pagination.current_page + 1}" variant="ghost" size="sm">다음 →</Button>
          {/if}
        </div>
      {/if}
    {/if}
  </div>
</AppShell>
