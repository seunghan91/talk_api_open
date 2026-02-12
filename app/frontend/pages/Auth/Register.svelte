<script>
  import { router } from "@inertiajs/svelte";
  import Button from "$components/common/Button.svelte";

  let nickname = $state("");
  let password = $state("");
  let password_confirmation = $state("");
  let gender = $state("unknown");
  let loading = $state(false);
  let errors = $state({});

  const genderOptions = [
    { value: "unknown", label: "선택 안함" },
    { value: "male", label: "남성" },
    { value: "female", label: "여성" },
  ];

  function handleSubmit(e) {
    e.preventDefault();
    const newErrors = {};

    if (!nickname.trim() || nickname.length < 2) {
      newErrors.nickname = "닉네임은 2자 이상이어야 합니다.";
    }
    if (password.length < 6) {
      newErrors.password = "비밀번호는 6자 이상이어야 합니다.";
    }
    if (password !== password_confirmation) {
      newErrors.password_confirmation = "비밀번호가 일치하지 않습니다.";
    }

    if (Object.keys(newErrors).length > 0) {
      errors = newErrors;
      return;
    }

    loading = true;
    errors = {};

    router.post("/auth/register", {
      nickname,
      password,
      password_confirmation,
      gender,
    }, {
      onFinish: () => { loading = false; },
      onError: (err) => { errors = err; },
    });
  }
</script>

<div class="flex min-h-screen items-center justify-center bg-gradient-to-br from-sky-50 via-white to-cyan-50 px-4 py-8">
  <div class="w-full max-w-sm">
    <!-- 헤더 -->
    <div class="mb-8 text-center">
      <div class="mb-3 text-5xl">🎉</div>
      <h1 class="text-2xl font-bold text-slate-900">프로필 설정</h1>
      <p class="mt-2 text-sm text-slate-500">Talkk에서 사용할 프로필을 만들어주세요</p>
    </div>

    <!-- 회원가입 폼 -->
    <form onsubmit={handleSubmit} class="space-y-4">
      <!-- 닉네임 -->
      <div>
        <label for="nickname" class="mb-1.5 block text-sm font-medium text-slate-700">닉네임</label>
        <input
          id="nickname"
          type="text"
          bind:value={nickname}
          placeholder="2자 이상 닉네임을 입력하세요"
          class="w-full rounded-xl border border-slate-200 bg-white px-4 py-3 text-slate-900 outline-none transition-colors focus:border-sky-400 focus:ring-2 focus:ring-sky-100 placeholder:text-slate-400"
          maxlength="20"
        />
        {#if errors.nickname}
          <p class="mt-1 text-xs text-rose-500">{errors.nickname}</p>
        {/if}
      </div>

      <!-- 성별 -->
      <div>
        <p id="register-gender-label" class="mb-1.5 block text-sm font-medium text-slate-700">성별</p>
        <div class="flex gap-2" role="radiogroup" aria-labelledby="register-gender-label">
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

      <!-- 비밀번호 -->
      <div>
        <label for="password" class="mb-1.5 block text-sm font-medium text-slate-700">비밀번호</label>
        <input
          id="password"
          type="password"
          bind:value={password}
          placeholder="6자 이상"
          class="w-full rounded-xl border border-slate-200 bg-white px-4 py-3 text-slate-900 outline-none transition-colors focus:border-sky-400 focus:ring-2 focus:ring-sky-100 placeholder:text-slate-400"
        />
        {#if errors.password}
          <p class="mt-1 text-xs text-rose-500">{errors.password}</p>
        {/if}
      </div>

      <!-- 비밀번호 확인 -->
      <div>
        <label for="password_confirm" class="mb-1.5 block text-sm font-medium text-slate-700">비밀번호 확인</label>
        <input
          id="password_confirm"
          type="password"
          bind:value={password_confirmation}
          placeholder="비밀번호를 다시 입력하세요"
          class="w-full rounded-xl border border-slate-200 bg-white px-4 py-3 text-slate-900 outline-none transition-colors focus:border-sky-400 focus:ring-2 focus:ring-sky-100 placeholder:text-slate-400"
        />
        {#if errors.password_confirmation}
          <p class="mt-1 text-xs text-rose-500">{errors.password_confirmation}</p>
        {/if}
      </div>

      <Button type="submit" variant="primary" size="xl" {loading} class="mt-2 w-full">
        {loading ? "가입 중..." : "시작하기"}
      </Button>
    </form>
  </div>
</div>
