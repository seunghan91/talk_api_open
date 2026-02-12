<script>
  import { router } from "@inertiajs/svelte";
  import AppShell from "$components/layout/AppShell.svelte";
  import Card from "$components/common/Card.svelte";
  import Button from "$components/common/Button.svelte";
  import { theme } from "$lib/stores.js";

  let { settings = {} } = $props();
</script>

<AppShell>
  <h1 class="mb-6 text-2xl font-bold text-slate-900">⚙️ 설정</h1>

  <!-- 테마 설정 -->
  <Card class="mb-4">
    <h2 class="mb-4 text-lg font-semibold text-slate-900">화면</h2>
    <div class="flex items-center justify-between">
      <div>
        <p class="font-medium text-slate-900">다크 모드</p>
        <p class="text-sm text-slate-500">어두운 테마를 사용합니다</p>
      </div>
      <button
        onclick={() => theme.toggle()}
        aria-label="다크 모드 토글"
        class="relative inline-flex h-6 w-11 items-center rounded-full transition-colors
          {$theme === 'dark' ? 'bg-sky-500' : 'bg-slate-200'}"
      >
        <span
          class="inline-block h-4 w-4 transform rounded-full bg-white transition-transform
            {$theme === 'dark' ? 'translate-x-6' : 'translate-x-1'}"
        ></span>
      </button>
    </div>
  </Card>

  <!-- 알림 설정 -->
  <Card class="mb-4">
    <h2 class="mb-4 text-lg font-semibold text-slate-900">알림</h2>
    <div class="space-y-4">
      <div class="flex items-center justify-between">
        <div>
          <p class="font-medium text-slate-900">푸시 알림</p>
          <p class="text-sm text-slate-500">새 메시지, 브로드캐스트 알림</p>
        </div>
        <div class="h-6 w-11 rounded-full bg-sky-500 relative">
          <span class="absolute right-1 top-1 h-4 w-4 rounded-full bg-white"></span>
        </div>
      </div>
    </div>
  </Card>

  <!-- 계정 -->
  <Card class="mb-4">
    <h2 class="mb-4 text-lg font-semibold text-slate-900">계정</h2>
    <div class="space-y-3">
      <a href="/profile" class="flex items-center justify-between rounded-lg p-2 transition-colors hover:bg-slate-50">
        <span class="text-sm text-slate-700">프로필 수정</span>
        <span class="text-slate-400">→</span>
      </a>
      <div class="flex items-center justify-between rounded-lg p-2">
        <span class="text-sm text-slate-700">차단한 사용자</span>
        <span class="text-sm text-slate-500">{settings.blocked_users_count || 0}명</span>
      </div>
    </div>
  </Card>

  <!-- 로그아웃 -->
  <Card>
    <form method="post" action="/auth/logout">
      <input type="hidden" name="_method" value="delete" />
      <Button type="submit" variant="ghost" size="md" class="w-full text-rose-500 hover:bg-rose-50 hover:text-rose-600">
        로그아웃
      </Button>
    </form>
  </Card>

  <!-- 버전 정보 -->
  <p class="mt-6 text-center text-xs text-slate-400">Talkk v1.0.0</p>
</AppShell>
