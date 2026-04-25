<template>
  <div class="dashboard-home">
    <!-- 欢迎区域 -->
    <div class="welcome-section">
      <div class="welcome-content">
        <div class="welcome-text">
          <h1 class="welcome-greeting">{{ greeting }}</h1>
          <p class="welcome-subtitle">{{ welcomeMessage }}</p>
        </div>
        <div class="welcome-info">
          <div class="system-status">
            <span class="status-dot online"></span>
            <span>系统运行正常</span>
          </div>
        </div>
      </div>
    </div>

    <!-- 轮播图 -->
    <NCard class="carousel-card" :bordered="false">
      <NCarousel
        :show-dots="true"
        :autoplay="true"
        :interval="2000"
        :loop="true"
        style="height: 500px; border-radius: 8px; overflow: hidden;"
      >
        <div class="carousel-item">
          <img src="@/assets/images/1.png" alt="轮播图1" class="carousel-image" />
        </div>
        <div class="carousel-item">
          <img src="@/assets/images/2.png" alt="轮播图2" class="carousel-image" />
        </div>
      </NCarousel>
    </NCard>

    <!-- 待办事项 -->
    <NCard class="content-card" title="待办事项" :bordered="false" :loading="loading">
      <div class="todos-grid">
        <div
          v-for="item in todoItems"
          :key="item.key"
          class="todo-item"
          @click="handleTodoClick(item)"
        >
          <div class="todo-icon">
            <span :style="{ color: item.color }">{{ item.icon }}</span>
          </div>
          <div class="todo-content">
            <div class="todo-title">{{ item.title }}</div>
            <div class="todo-desc">{{ item.description }}</div>
          </div>
          <div class="todo-count">
            <NBadge :value="item.count" :max="99" :show="item.count > 0" />
          </div>
        </div>
      </div>
    </NCard>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { NCard, NBadge, NCarousel, useMessage } from 'naive-ui'
import dayjs from 'dayjs'
import { useUserStore } from '@/store/user'
import { getTodoStats } from '@/api/dashboard'

const router = useRouter()
const message = useMessage()
const userStore = useUserStore()

// 加载状态
const loading = ref(false)

// 动态问候语
const greeting = computed(() => {
  const hour = dayjs().hour()
  if (hour < 6) return '凌晨好'
  if (hour < 9) return '早上好'
  if (hour < 12) return '上午好'
  if (hour < 14) return '中午好'
  if (hour < 17) return '下午好'
  if (hour < 19) return '傍晚好'
  return '晚上好'
})

const welcomeMessage = computed(() => {
  return `${greeting.value}，${userStore.displayName()}！今天又是充满希望的一天！`
})

// 待办事项数据
const todoItems = ref([
  {
    key: 'pending-jobs',
    title: '待审核职位',
    description: '需要审核的招聘职位',
    icon: '📋',
    color: '#2f7cff',
    count: 0,
    path: '/dashboard/review'
  },
  {
    key: 'pending-reports',
    title: '待处理举报',
    description: '需要处理的用户举报',
    icon: '⚠️',
    color: '#faad14',
    count: 0,
    path: '/dashboard/reports'
  }
])

// 加载待办事项数据
const loadTodoData = async () => {
  loading.value = true
  try {
    const stats = await getTodoStats()

    // 更新待办事项数量
    todoItems.value = todoItems.value.map(item => {
      if (item.key === 'pending-jobs') {
        item.count = stats.pendingJobs
      } else if (item.key === 'pending-reports') {
        item.count = stats.pendingReports
      }
      return item
    })
  } catch (error) {
    console.error('加载待办事项数据失败:', error)
    message.error('加载待办事项失败')
  } finally {
    loading.value = false
  }
}

// 处理待办事项点击
const handleTodoClick = (item: any) => {
  if (item.path) {
    router.push(item.path)
  } else {
    message.info(`${item.title}功能开发中`)
  }
}

// 初始化页面数据
onMounted(() => {
  loadTodoData()
})
</script>

<style scoped lang="scss">
.dashboard-home {
  // 欢迎区域样式
  .welcome-section {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 32px;
    margin-bottom: 32px;
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    border-radius: 16px;
    color: white;
    box-shadow: 0 8px 32px rgba(102, 126, 234, 0.3);

    .welcome-content {
      flex: 1;

      .welcome-text {
        margin-bottom: 20px;

        .welcome-greeting {
          font-size: 32px;
          font-weight: 700;
          margin: 0 0 8px 0;
        }

        .welcome-subtitle {
          font-size: 16px;
          opacity: 0.9;
          margin: 0;
        }
      }

      .welcome-info {
        display: flex;
        gap: 24px;
        font-size: 14px;

        .system-status {
          display: flex;
          align-items: center;
          gap: 8px;

          .status-dot {
            width: 8px;
            height: 8px;
            border-radius: 50%;

            &.online {
              background: #52c41a;
              box-shadow: 0 0 8px rgba(82, 196, 26, 0.6);
            }
          }
        }
      }
    }
  }

  .carousel-card {
    margin-bottom: 24px;
  }

  .carousel-item {
    width: 100%;
    height: 100%;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .carousel-image {
    width: 100%;
    height: 100%;
    object-fit: cover;
  }

  .content-card {
    margin-bottom: 24px;
  }

  .todos-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
    gap: 16px;
  }

  .todo-item {
    display: flex;
    align-items: center;
    padding: 24px;
    border: 1px solid var(--border-color);
    border-radius: 12px;
    background: var(--bg-primary);
    cursor: pointer;
    transition: all 0.2s ease;
    position: relative;

    &:hover {
      border-color: var(--primary-color);
      box-shadow: 0 4px 12px rgba(47, 124, 255, 0.15);
      transform: translateY(-2px);
    }
  }

  .todo-icon {
    font-size: 32px;
    margin-right: 20px;
    flex-shrink: 0;
  }

  .todo-content {
    flex: 1;

    .todo-title {
      font-size: 18px;
      font-weight: 600;
      color: var(--text-primary);
      margin-bottom: 8px;
    }

    .todo-desc {
      font-size: 14px;
      color: var(--text-secondary);
    }
  }

  .todo-count {
    position: absolute;
    right: 24px;
    top: 50%;
    transform: translateY(-50%);
  }
}

// 响应式设计
@media (max-width: 768px) {
  .dashboard-home {
    .welcome-section {
      flex-direction: column;
      gap: 24px;
      text-align: center;
      padding: 24px;

      .welcome-content {
        .welcome-text {
          .welcome-greeting {
            font-size: 24px;
          }
        }

        .welcome-info {
          flex-direction: column;
          gap: 12px;
        }
      }
    }

    .todos-grid {
      grid-template-columns: 1fr;
    }

    .todo-item {
      padding: 20px;
    }

    .todo-icon {
      font-size: 28px;
      margin-right: 16px;
    }
  }
}
</style>