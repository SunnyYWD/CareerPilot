import { createApp } from 'vue'
import { createPinia } from 'pinia'
import naive, { createDiscreteApi } from 'naive-ui'
import { darkTheme, lightTheme } from 'naive-ui'

import 'uno.css'
import '@/styles/index.css'

import App from './App.vue'
import router from './router'
import { useThemeStore } from '@/store/theme'
import { useUserStore } from '@/store/user'

const app = createApp(App)
const pinia = createPinia()

app.use(pinia)

// 初始化主题
const themeStore = useThemeStore()
themeStore.initTheme()

// 初始化用户认证状态
const userStore = useUserStore()
userStore.initAuth()

// 监控localStorage变化
const originalSetItem = localStorage.setItem
const originalRemoveItem = localStorage.removeItem
const originalClear = localStorage.clear

localStorage.setItem = function (key, value) {
  if (key.startsWith('auth-')) {
    console.log('📝 localStorage.setItem 被调用:', key, value)
  }
  return originalSetItem.call(this, key, value)
}

localStorage.removeItem = function (key) {
  if (key.startsWith('auth-')) {
    console.log('🗑️ localStorage.removeItem 被调用:', key)
  }
  return originalRemoveItem.call(this, key)
}

localStorage.clear = function () {
  console.log('🧹 localStorage.clear 被调用!')
  console.trace('调用堆栈:')
  return originalClear.call(this)
}

// 配置 Naive UI
const { message, notification, dialog, loadingBar } = createDiscreteApi(
  ['message', 'dialog', 'notification', 'loadingBar'],
  {
    configProviderProps: () => ({
      theme: themeStore.isDark ? darkTheme : lightTheme
    })
  }
)

// 设置全局 Naive UI 实例
app.provide('naive', {
  message,
  notification,
  dialog,
  loadingBar,
  theme: themeStore.isDark ? darkTheme : lightTheme
})

// 将 Naive UI 实例挂载到 window 以便主题 store 使用
window.$naive = {
  message,
  notification,
  dialog,
  loadingBar,
  theme: themeStore.isDark ? darkTheme : lightTheme
}

app.use(router)
app.use(naive, {
  configProviderProps: () => ({
    theme: themeStore.isDark ? darkTheme : lightTheme
  })
})

app.mount('#app')