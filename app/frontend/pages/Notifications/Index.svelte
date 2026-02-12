<script>
  import { router } from "@inertiajs/svelte";
  import AppShell from "$components/layout/AppShell.svelte";
  import Card from "$components/common/Card.svelte";
  import Button from "$components/common/Button.svelte";
  import EmptyState from "$components/common/EmptyState.svelte";
  import { timeAgo } from "$lib/utils.js";

  let { notifications = [], pagination = {}, unread_count = 0 } = $props();

  const typeIcons = {
    broadcast: "📢",
    message: "💬",
    system: "ℹ️",
    report: "🚨",
  };

  function markAllRead() {
    router.patch("/notifications/mark_all_read");
  }
</script>

<AppShell>
  <div class="mb-6 flex items-center justify-between">
    <h1 class="text-2xl font-bold text-slate-900">🔔 알림</h1>
    {#if unread_count > 0}
      <Button onclick={markAllRead} variant="ghost" size="sm">
        모두 읽음 처리
      </Button>
    {/if}
  </div>

  {#if notifications.length === 0}
    <EmptyState
      icon="🔔"
      title="알림이 없어요"
      description="새로운 소식이 생기면 여기서 확인할 수 있어요"
    />
  {:else}
    <div class="space-y-2">
      {#each notifications as notification (notification.id)}
        <Card padding={false} class="px-4 py-3 {notification.read ? '' : 'border-l-4 border-l-sky-500 bg-sky-50/50'}">
          <div class="flex items-start gap-3">
            <span class="mt-0.5 text-xl">{typeIcons[notification.notification_type] || "📌"}</span>
            <div class="flex-1 min-w-0">
              <p class="text-sm font-medium text-slate-900">{notification.title}</p>
              {#if notification.body}
                <p class="mt-0.5 text-sm text-slate-500">{notification.body}</p>
              {/if}
              <p class="mt-1 text-xs text-slate-400">{timeAgo(notification.created_at)}</p>
            </div>
            {#if !notification.read}
              <div class="mt-1 h-2 w-2 flex-shrink-0 rounded-full bg-sky-500"></div>
            {/if}
          </div>
        </Card>
      {/each}
    </div>
  {/if}
</AppShell>
