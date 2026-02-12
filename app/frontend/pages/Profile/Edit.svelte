<script>
  import { router } from "@inertiajs/svelte";
  import AppShell from "$components/layout/AppShell.svelte";
  import Card from "$components/common/Card.svelte";
  import Button from "$components/common/Button.svelte";
  import { onMount } from "svelte";

  let { profile = {} } = $props();

  let nickname = $state("");
  let gender = $state("unknown");
  let bio = $state("");
  let loading = $state(false);
  let errors = $state({});

  const genderOptions = [
    { value: "unknown", label: "선택 안함" },
    { value: "male", label: "남성" },
    { value: "female", label: "여성" },
  ];

  onMount(() => {
    nickname = profile.nickname || "";
    gender = profile.gender || "unknown";
    bio = profile.bio || "";
  });

  function handleSubmit(e) {
    e.preventDefault();
    loading = true;
    errors = {};

    router.patch("/profile", { nickname, gender, bio }, {
      onFinish: () => { loading = false; },
      onError: (err) => { errors = err; },
    });
  }
</script>

<AppShell>
  <div class="mx-auto max-w-md">
    <div class="mb-4">
      <a href="/profile" class="text-sm text-slate-500 hover:text-sky-600">← 프로필</a>
    </div>

    <h1 class="mb-6 text-2xl font-bold text-slate-900">프로필 수정</h1>

    <Card>
      <form onsubmit={handleSubmit} class="space-y-4">
        <div>
          <label for="nickname" class="mb-1.5 block text-sm font-medium text-slate-700">닉네임</label>
          <input
            id="nickname"
            type="text"
            bind:value={nickname}
            class="w-full rounded-xl border border-slate-200 bg-white px-4 py-3 text-slate-900 outline-none transition-colors focus:border-sky-400 focus:ring-2 focus:ring-sky-100"
            maxlength="20"
          />
          {#if errors.nickname}
            <p class="mt-1 text-xs text-rose-500">{errors.nickname}</p>
          {/if}
        </div>

        <div>
          <p id="profile-gender-label" class="mb-1.5 block text-sm font-medium text-slate-700">성별</p>
          <div class="flex gap-2" role="radiogroup" aria-labelledby="profile-gender-label">
            {#each genderOptions as option}
              <button
                type="button"
                onclick={() => { gender = option.value; }}
                role="radio"
                aria-checked={gender === option.value}
                class="flex-1 rounded-xl border px-4 py-2.5 text-sm font-medium transition-all
                  {gender === option.value
                    ? 'border-sky-400 bg-sky-50 text-sky-700'
                    : 'border-slate-200 bg-white text-slate-600 hover:border-slate-300'}"
              >
                {option.label}
              </button>
            {/each}
          </div>
        </div>

        <div>
          <label for="bio" class="mb-1.5 block text-sm font-medium text-slate-700">자기소개</label>
          <textarea
            id="bio"
            bind:value={bio}
            placeholder="간단한 자기소개를 입력하세요"
            rows="3"
            class="w-full resize-none rounded-xl border border-slate-200 bg-white px-4 py-3 text-slate-900 outline-none transition-colors focus:border-sky-400 focus:ring-2 focus:ring-sky-100 placeholder:text-slate-400"
            maxlength="100"
          ></textarea>
        </div>

        <Button type="submit" variant="primary" size="lg" {loading} class="w-full">
          {loading ? "저장 중..." : "저장"}
        </Button>
      </form>
    </Card>
  </div>
</AppShell>
