<script>
  import AppShell from "$components/layout/AppShell.svelte";
  import Card from "$components/common/Card.svelte";
  import Button from "$components/common/Button.svelte";
  import Avatar from "$components/common/Avatar.svelte";

  let { profile = {} } = $props();

  const genderLabels = { unknown: "미설정", male: "남성", female: "여성" };
</script>

<AppShell>
  <div class="mx-auto max-w-md">
    <!-- 프로필 카드 -->
    <Card class="text-center">
      <div class="flex flex-col items-center">
        <Avatar userId={profile.id} nickname={profile.nickname} size="xl" />
        <h1 class="mt-4 text-xl font-bold text-slate-900">{profile.nickname}</h1>
        <p class="mt-1 text-sm text-slate-500">{profile.phone_number}</p>

        {#if profile.bio}
          <p class="mt-3 text-sm text-slate-600">{profile.bio}</p>
        {/if}

        <div class="mt-6 flex gap-8">
          <div class="text-center">
            <p class="text-lg font-bold text-sky-600">{profile.broadcasts_count || 0}</p>
            <p class="text-xs text-slate-500">방송</p>
          </div>
          <div class="text-center">
            <p class="text-lg font-bold text-sky-600">{profile.conversations_count || 0}</p>
            <p class="text-xs text-slate-500">대화</p>
          </div>
        </div>

        <Button href="/profile/edit" variant="secondary" size="md" class="mt-6 w-full">
          프로필 수정
        </Button>
      </div>
    </Card>

    <!-- 상세 정보 -->
    <Card class="mt-4">
      <div class="space-y-3">
        <div class="flex items-center justify-between">
          <span class="text-sm text-slate-500">성별</span>
          <span class="text-sm font-medium text-slate-900">{genderLabels[profile.gender] || "미설정"}</span>
        </div>
        <div class="flex items-center justify-between">
          <span class="text-sm text-slate-500">연령대</span>
          <span class="text-sm font-medium text-slate-900">{profile.age_range || "미설정"}</span>
        </div>
        <div class="flex items-center justify-between">
          <span class="text-sm text-slate-500">가입일</span>
          <span class="text-sm font-medium text-slate-900">
            {new Date(profile.created_at).toLocaleDateString("ko-KR")}
          </span>
        </div>
      </div>
    </Card>

    <!-- 로그아웃 -->
    <div class="mt-6 text-center">
      <form method="post" action="/auth/logout">
        <input type="hidden" name="_method" value="delete" />
        <Button type="submit" variant="ghost" size="sm" class="text-rose-500 hover:text-rose-600">
          로그아웃
        </Button>
      </form>
    </div>
  </div>
</AppShell>
