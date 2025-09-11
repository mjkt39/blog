.PHONY: help serve build clean add deploy

# デフォルトタスク
help: ## ヘルプを表示
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

serve: ## ローカルサーバーを起動 (http://localhost:1313)
	@echo "🚀 Starting Hugo server..."
	@hugo server -D --bind 0.0.0.0

build: ## 本番用ビルド
	@echo "🔨 Building site..."
	@hugo --gc --minify
	@echo "✅ Build complete! Check ./public directory"

clean: ## publicディレクトリをクリーン
	@echo "🧹 Cleaning public directory..."
	@rm -rf public/*
	@echo "✅ Cleaned!"

add: ## 新しい記事を作成（対話式）
	@echo "📝 Creating new post..."
	@read -p "Enter post slug (e.g., my-new-post): " slug; \
	read -p "Enter post title: " title; \
	read -p "Enter tags (comma-separated): " tags; \
	filename="content/posts/$$slug.md"; \
	hugo new posts/$$slug.md; \
	echo "---" > $$filename; \
	echo "title: \"$$title\"" >> $$filename; \
	echo "date: $$(date +%Y-%m-%dT%H:%M:%S+09:00)" >> $$filename; \
	echo "draft: false" >> $$filename; \
	echo -n "tags: [" >> $$filename; \
	echo "$$tags" | sed 's/,/", "/g' | sed 's/^/"/;s/$$/"/' | tr -d '\n' >> $$filename; \
	echo "]" >> $$filename; \
	echo "---" >> $$filename; \
	echo "" >> $$filename; \
	echo "<!-- ここに記事の内容を書いてください -->" >> $$filename; \
	echo "" >> $$filename; \
	echo "✅ Created: $$filename"; \
	echo "📝 Opening in editor..."; \
	code $$filename 2>/dev/null || vim $$filename 2>/dev/null || nano $$filename 2>/dev/null || echo "Please open $$filename in your editor"

deploy: build ## GitHub Pagesにデプロイ
	@echo "🚀 Deploying to GitHub Pages..."
	@git add .
	@git status
	@read -p "Commit message: " msg; \
	git commit -m "$$msg"
	@git push origin main
	@echo "✅ Deployed! Changes will be live in a few minutes."

preview: ## 新しい記事のプレビュー（最新の下書きを表示）
	@echo "👁️  Previewing drafts..."
	@hugo server -D --buildDrafts --bind 0.0.0.0

list: ## 記事一覧を表示
	@echo "📚 Posts list:"
	@echo "=================="
	@find content/posts -name "*.md" -type f | while read file; do \
		title=$$(grep "^title:" "$$file" | head -1 | sed 's/title: //g' | sed 's/"//g'); \
		date=$$(grep "^date:" "$$file" | head -1 | sed 's/date: //g' | cut -d'T' -f1); \
		draft=$$(grep "^draft:" "$$file" | head -1 | sed 's/draft: //g'); \
		if [ "$$draft" = "true" ]; then \
			printf "\033[33m[DRAFT]\033[0m "; \
		fi; \
		printf "$$date - $$title\n"; \
	done | sort -r

stats: ## サイト統計を表示
	@echo "📊 Site Statistics:"
	@echo "=================="
	@echo "Total posts: $$(find content/posts -name "*.md" -type f | wc -l | tr -d ' ')"
	@echo "Draft posts: $$(grep -l "draft: true" content/posts/*.md 2>/dev/null | wc -l | tr -d ' ')"
	@echo "Published posts: $$(grep -l "draft: false" content/posts/*.md 2>/dev/null | wc -l | tr -d ' ')"
	@echo "Total words: $$(find content/posts -name "*.md" -type f -exec cat {} \; | wc -w | tr -d ' ')"