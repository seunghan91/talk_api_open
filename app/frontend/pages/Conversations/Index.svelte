<script>
  import AppShell from "$components/layout/AppShell.svelte";
  import Card from "$components/common/Card.svelte";
  import Avatar from "$components/common/Avatar.svelte";
  import Badge from "$components/common/Badge.svelte";
  import EmptyState from "$components/common/EmptyState.svelte";
  import { timeAgo } from "$lib/utils.js";

  let { conversations = [], pagination = {} } = $props();

  let favorites = $derived(conversations.filter(c => c?.is_favorited));
  let others = $derived(conversations.filter(c => c && !c.is_favorited));
</script>

<AppShell>
  <h1 class="mb-6 text-2xl font-bold text-slate-900">💬 대화</h1>

  {#if conversations.length === 0}
    <EmptyState
      icon="💬"
      title="대화가 없어요"
      description="브로드캐스트에 답장하면 대화가 시작됩니다"
    />
  {:else}
    <!-- 즐겨찾기 -->
    {#if favorites.length > 0}
      <div class="mb-6">
        <h2 class="mb-3 flex items-center gap-2 text-sm font-semibold text-slate-500">
          ⭐ 즐겨찾기
        </h2>
        <div class="space-y-2">
          {#each favorites as conv (conv.id)}
            <a href="/conversations/{conv.id}" class="block">
              <Card hover padding={false} class="px-4 py-3">
                <div class="flex items-center gap-3">
                  <Avatar userId={conv.other_user?.id} nickname={conv.other_user?.nickname} />
                  <div class="flex-1 min-w-0">
                    <div class="flex items-center justify-between">
                      <span class="font-medium text-slate-900">{conv.other_user?.nickname}</span>
                      <span class="text-xs text-slate-400">{timeAgo(conv.updated_at)}</span>
                    </div>
                    {#if conv.last_message}
                      <p class="mt-0.5 truncate text-sm text-slate-500">
                        {conv.last_message.is_voice ? "🔊 음성 메시지" : conv.last_message.content}
                      </p>
                    {/if}
                  </div>
                  {#if conv.unread_count > 0}
                    <Badge variant="primary">{conv.unread_count}</Badge>
                  {/if}
                </div>
              </Card>
            </a>
          {/each}
        </div>
      </div>
    {/if}

    <!-- 전체 대화 -->
    <div>
      <h2 class="mb-3 text-sm font-semibold text-slate-500">💬 전체 대화</h2>
      <div class="space-y-2">
        {#each others as conv (conv.id)}
          <a href="/conversations/{conv.id}" class="block">
            <Card hover padding={false} class="px-4 py-3">
              <div class="flex items-center gap-3">
                <Avatar userId={conv.other_user?.id} nickname={conv.other_user?.nickname} />
                <div class="flex-1 min-w-0">
                  <div class="flex items-center justify-between">
                    <span class="font-medium text-slate-900">{conv.other_user?.nickname}</span>
                    <span class="text-xs text-slate-400">{timeAgo(conv.updated_at)}</span>
                  </div>
                  {#if conv.last_message}
                    <p class="mt-0.5 truncate text-sm text-slate-500">
                      {conv.last_message.is_voice ? "🔊 음성 메시지" : conv.last_message.content}
                    </p>
                  {/if}
                </div>
                {#if conv.unread_count > 0}
                  <Badge variant="primary">{conv.unread_count}</Badge>
                {/if}
              </div>
            </Card>
          </a>
        {/each}
      </div>
    </div>
  {/if}
</AppShell>
