<script>
  import { router } from "@inertiajs/svelte";
  import Card from "$components/common/Card.svelte";
  import Button from "$components/common/Button.svelte";
  import Badge from "$components/common/Badge.svelte";

  let { users = [], pagination = {}, filter = null } = $props();

  function suspendUser(userId) {
    if (confirm("이 사용자를 정지하시겠습니까?")) {
      router.put(`/admin/users/${userId}/suspend`, {
        duration: 7,
        reason: "관리자에 의한 정지",
      });
    }
  }

  function unsuspendUser(userId) {
    if (confirm("이 사용자의 정지를 해제하시겠습니까?")) {
      router.put(`/admin/users/${userId}/unsuspend`);
    }
  }
</script>

<div class="min-h-screen bg-slate-50">
  <header class="border-b border-slate-200 bg-white px-6 py-4">
    <div class="flex items-center gap-3">
      <a href="/admin" class="text-slate-500 hover:text-slate-700">← 대시보드</a>
      <h1 class="text-xl font-bold text-slate-900">👥 사용자 관리</h1>
    </div>
  </header>

  <main class="p-6">
    <!-- 필터 -->
    <div class="mb-4 flex gap-2">
      <Button href="/admin/users" variant={!filter ? "primary" : "secondary"} size="sm">전체</Button>
      <Button href="/admin/users?status=blocked" variant={filter === "blocked" ? "primary" : "secondary"} size="sm">차단됨</Button>
    </div>

    <Card padding={false}>
      <div class="overflow-x-auto">
        <table class="w-full">
          <thead>
            <tr class="border-b border-slate-200 bg-slate-50">
              <th class="px-4 py-3 text-left text-xs font-semibold text-slate-500">ID</th>
              <th class="px-4 py-3 text-left text-xs font-semibold text-slate-500">닉네임</th>
              <th class="px-4 py-3 text-left text-xs font-semibold text-slate-500">상태</th>
              <th class="px-4 py-3 text-left text-xs font-semibold text-slate-500">방송</th>
              <th class="px-4 py-3 text-left text-xs font-semibold text-slate-500">가입일</th>
              <th class="px-4 py-3 text-left text-xs font-semibold text-slate-500">관리</th>
            </tr>
          </thead>
          <tbody>
            {#each users as user (user.id)}
              <tr class="border-b border-slate-100 hover:bg-slate-50">
                <td class="px-4 py-3 text-sm text-slate-600">{user.id}</td>
                <td class="px-4 py-3 text-sm font-medium text-slate-900">{user.nickname}</td>
                <td class="px-4 py-3">
                  {#if user.blocked}
                    <Badge variant="danger">차단됨</Badge>
                  {:else}
                    <Badge variant="success">활성</Badge>
                  {/if}
                </td>
                <td class="px-4 py-3 text-sm text-slate-600">{user.broadcasts_count}</td>
                <td class="px-4 py-3 text-sm text-slate-500">
                  {new Date(user.created_at).toLocaleDateString("ko-KR")}
                </td>
                <td class="px-4 py-3">
                  {#if user.blocked}
                    <Button onclick={() => unsuspendUser(user.id)} variant="ghost" size="sm">
                      해제
                    </Button>
                  {:else}
                    <Button onclick={() => suspendUser(user.id)} variant="ghost" size="sm" class="text-rose-500">
                      정지
                    </Button>
                  {/if}
                </td>
              </tr>
            {/each}
          </tbody>
        </table>
      </div>
    </Card>

    <!-- 페이지네이션 -->
    {#if pagination.total_pages > 1}
      <div class="mt-4 flex justify-center gap-2">
        {#if pagination.current_page > 1}
          <Button href="/admin/users?page={pagination.current_page - 1}" variant="ghost" size="sm">← 이전</Button>
        {/if}
        <span class="flex items-center text-sm text-slate-500">{pagination.current_page} / {pagination.total_pages}</span>
        {#if pagination.current_page < pagination.total_pages}
          <Button href="/admin/users?page={pagination.current_page + 1}" variant="ghost" size="sm">다음 →</Button>
        {/if}
      </div>
    {/if}
  </main>
</div>
