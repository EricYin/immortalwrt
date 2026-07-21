#!/bin/bash
#
# git-upload.sh —— 一键 add + commit + push + 创建 PR
#
# 用法:
#   ./git-upload.sh "提交说明"
#   ./git-upload.sh "提交说明" my-feature-branch
#   ./git-upload.sh                     # 不传参数则弹出交互式输入
#
# 依赖:
#   - git（必须）
#   - gh  （可选，用于自动创建 PR；没安装则只推送，不开 PR）
#
# 首次使用前：
#   chmod +x git-upload.sh
#   gh auth login   # 如果要自动开 PR

set -euo pipefail

# ---------- 可按需修改的默认配置 ----------
DEFAULT_BASE_BRANCH="openwrt-24.10-6.6"   # PR 目标分支，改成你仓库实际的默认分支
REMOTE="origin"
# ------------------------------------------

info()  { echo -e "\033[1;34m[信息]\033[0m $1"; }
ok()    { echo -e "\033[1;32m[完成]\033[0m $1"; }
warn()  { echo -e "\033[1;33m[提示]\033[0m $1"; }
err()   { echo -e "\033[1;31m[错误]\033[0m $1" >&2; }

# 0. 检查是否在 git 仓库里
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  err "当前目录不是一个 git 仓库，请先 cd 到仓库目录再运行。"
  exit 1
fi

# 1. 检查是否有改动
if git diff --quiet && git diff --cached --quiet && [ -z "$(git status --porcelain)" ]; then
  warn "没有检测到任何改动，无需提交。"
  exit 0
fi

# 2. 获取提交说明
COMMIT_MSG="${1:-}"
if [ -z "$COMMIT_MSG" ]; then
  read -rp "请输入提交说明: " COMMIT_MSG
  if [ -z "$COMMIT_MSG" ]; then
    err "提交说明不能为空。"
    exit 1
  fi
fi

# 3. 获取/创建分支
CURRENT_BRANCH="$(git branch --show-current)"
TARGET_BRANCH="${2:-$CURRENT_BRANCH}"

if [ "$TARGET_BRANCH" != "$CURRENT_BRANCH" ]; then
  info "切换/创建分支: $TARGET_BRANCH"
  git checkout -B "$TARGET_BRANCH"
fi

if [ "$TARGET_BRANCH" = "$DEFAULT_BASE_BRANCH" ] || [ "$TARGET_BRANCH" = "main" ] || [ "$TARGET_BRANCH" = "master" ]; then
  warn "你正在主分支上直接提交（$TARGET_BRANCH），建议改用功能分支。"
  read -rp "仍要继续吗？(y/N): " CONFIRM
  [ "$CONFIRM" = "y" ] || [ "$CONFIRM" = "Y" ] || { err "已取消。"; exit 1; }
fi

# 4. add + commit
info "添加改动文件..."
git add -A

info "提交中..."
git commit -s -m "$COMMIT_MSG"

# 5. push
info "推送到 $REMOTE/$TARGET_BRANCH ..."
git push -u "$REMOTE" "$TARGET_BRANCH"
ok "代码已推送。"

# 6. 尝试自动创建 PR（需要 gh 命令且已登录）
if command -v gh > /dev/null 2>&1; then
  if gh auth status > /dev/null 2>&1; then
    info "检测到 GitHub CLI，尝试创建 Pull Request..."
    if gh pr view "$TARGET_BRANCH" > /dev/null 2>&1; then
      warn "该分支已存在对应的 PR，跳过创建。"
      gh pr view "$TARGET_BRANCH" --web
    else
      gh pr create \
        --base "$DEFAULT_BASE_BRANCH" \
        --head "$TARGET_BRANCH" \
        --title "$COMMIT_MSG" \
        --fill \
        --web
      ok "PR 创建成功，已在浏览器中打开。"
    fi
  else
    warn "gh 未登录，跳过自动创建 PR。可运行 'gh auth login' 后重试，或手动去网页创建。"
  fi
else
  warn "未安装 GitHub CLI (gh)，跳过自动创建 PR。"
  warn "可在 https://cli.github.com/ 安装后重跑本脚本自动开 PR，或手动去网页创建。"
fi

ok "全部完成 ✅"
