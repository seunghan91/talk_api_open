<script>
  import { router } from "@inertiajs/svelte";
  import Card from "$components/common/Card.svelte";
  import Avatar from "$components/common/Avatar.svelte";
  import Button from "$components/common/Button.svelte";
  import VoicePlayer from "$components/voice/VoicePlayer.svelte";
  import { timeAgo } from "$lib/utils.js";

  let { conversation = {}, messages = [] } = $props();
  let messageInput = $state("");
  let sending = $state(false);

  function sendMessage(e) {
    e.preventDefault();
    if (!messageInput.trim()) return;

    sending = true;
    router.post(`/conversations/${conversation.id}/send_message`, {
      content: messageInput,
    }, {
      preserveScroll: true,
      onSuccess: () => { messageInput = ""; },
      onFinish: () => { sending = false; },
    });
  }
</script>

<div class="flex h-screen flex-col bg-white">
  <!-- 헤더 -->
  <header class="flex items-center gap-3 border-b border-slate-200 px-4 py-3">
    <a href="/conversations" class="text-slate-500 hover:text-slate-700">←</a>
    <Avatar userId={conversation.other_user?.id} nickname={conversation.other_user?.nickname} size="sm" />
    <div class="flex-1">
      <h1 class="font-semibold text-slate-900">{conversation.other_user?.nickname}</h1>
    </div>
    <button class="text-slate-400 hover:text-slate-600">⋮</button>
  </header>

  <!-- 메시지 목록 -->
  <div class="flex-1 overflow-y-auto px-4 py-4">
    {#if conversation.broadcast_id}
      <div class="mb-4 text-center">
        <span class="rounded-full bg-slate-100 px-3 py-1 text-xs text-slate-500">
          📢 브로드캐스트에서 시작된 대화
        </span>
      </div>
    {/if}

    <div class="space-y-3">
      {#each messages as message (message.id)}
        <div class="flex {message.is_mine ? 'justify-end' : 'justify-start'}">
          <div class="max-w-[75%] {message.is_mine
            ? 'rounded-2xl rounded-br-md bg-sky-500 px-4 py-2.5 text-white'
            : 'rounded-2xl rounded-bl-md bg-slate-100 px-4 py-2.5 text-slate-800'}">
            {#if message.is_voice && message.voice_url}
              <VoicePlayer
                src={message.voice_url}
                duration={message.duration}
                compact
                light={message.is_mine}
              />
            {:else}
              <p class="text-sm">{message.content}</p>
            {/if}
            <p class="mt-1 text-[10px] {message.is_mine ? 'text-sky-200' : 'text-slate-400'}">
              {timeAgo(message.created_at)}
            </p>
          </div>
        </div>
      {/each}
    </div>
  </div>

  <!-- 메시지 입력 -->
  <div class="border-t border-slate-200 bg-white p-3">
    <form onsubmit={sendMessage} class="flex items-center gap-2">
      <input
        type="text"
        bind:value={messageInput}
        placeholder="메시지를 입력하세요..."
        class="flex-1 rounded-xl border border-slate-200 bg-slate-50 px-4 py-2.5 text-sm text-slate-900 outline-none focus:border-sky-400 focus:bg-white focus:ring-2 focus:ring-sky-100 placeholder:text-slate-400"
      />
      <Button type="submit" variant="primary" size="md" loading={sending} disabled={!messageInput.trim()}>
        ➤
      </Button>
    </form>
  </div>
</div>
