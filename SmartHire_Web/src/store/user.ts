import { defineStore } from 'pinia'
import { ref } from 'vue'
import type { User } from '@/types'

interface AuthState {
  token: string | null
  user: User | null
  permissions: string[]
}

export const useUserStore = defineStore('user', () => {
  const auth = ref<AuthState>({
    token: null,
    user: null,
    permissions: []
  })

  // 初始化认证状态
  const initAuth = () => {
    const savedToken = localStorage.getItem('auth-token')
    const savedUser = localStorage.getItem('auth-user')
    const savedPermissions = localStorage.getItem('auth-permissions')

    console.log('初始化认证状态:')
    console.log('- 保存的token:', savedToken ? '存在' : '不存在')
    console.log('- 保存的用户:', savedUser)
    console.log('- 保存的权限:', savedPermissions)

    if (savedToken) {
      auth.value.token = savedToken
      console.log('- token已设置')
    }

    if (savedUser) {
      try {
        const parsedUser = JSON.parse(savedUser)
        auth.value.user = parsedUser
        console.log('- 用户数据已解析并设置:', parsedUser)
      } catch (error) {
        console.error('Failed to parse saved user:', error)
      }
    } else {
      console.warn('- 没有找到保存的用户数据')
    }

    if (savedPermissions) {
      try {
        const parsedPermissions = JSON.parse(savedPermissions)
        auth.value.permissions = parsedPermissions
        console.log('- 权限数据已解析并设置:', parsedPermissions)
      } catch (error) {
        console.error('Failed to parse saved permissions:', error)
      }
    }

    console.log('初始化完成，当前auth状态:', auth.value)
  }

  // 登录
  const login = (token: string, user: User, permissions: string[] = []) => {
    console.log('登录函数调用:')
    console.log('- token:', token)
    console.log('- user:', user)
    console.log('- permissions:', permissions)

    // 确保用户数据有效
    const validUser = user || {
      id: 0,
      username: 'unknown',
      userType: 1,
      status: 1
    }

    auth.value = {
      token,
      user: validUser,
      permissions
    }

    console.log('设置后的auth状态:', auth.value)

    // 保存到本地存储
    try {
      localStorage.setItem('auth-token', token)
      localStorage.setItem('auth-user', JSON.stringify(validUser))
      localStorage.setItem('auth-permissions', JSON.stringify(permissions))

      // 验证保存是否成功
      const savedToken = localStorage.getItem('auth-token')
      const savedUser = localStorage.getItem('auth-user')
      const savedPermissions = localStorage.getItem('auth-permissions')

      console.log('localStorage验证结果:')
      console.log('- token保存成功:', !!savedToken)
      console.log('- 用户数据保存成功:', !!savedUser)
      console.log('- 权限数据保存成功:', !!savedPermissions)
    } catch (error) {
      console.error('保存到localStorage失败:', error)
    }
  }

  // 登出
  const logout = () => {
    console.log('🚨 LOGOUT方法被调用! 调用堆栈:', new Error().stack)
    console.log('清除前的localStorage:')
    console.log('- token:', localStorage.getItem('auth-token'))
    console.log('- user:', localStorage.getItem('auth-user'))
    console.log('- permissions:', localStorage.getItem('auth-permissions'))

    auth.value = {
      token: null,
      user: null,
      permissions: []
    }

    // 清除本地存储
    localStorage.removeItem('auth-token')
    localStorage.removeItem('auth-user')
    localStorage.removeItem('auth-permissions')

    console.log('清除后的localStorage:')
    console.log('- token:', localStorage.getItem('auth-token'))
    console.log('- user:', localStorage.getItem('auth-user'))
    console.log('- permissions:', localStorage.getItem('auth-permissions'))
  }

  // 更新用户信息
  const updateUser = (user: Partial<User>) => {
    if (auth.value.user) {
      auth.value.user = { ...auth.value.user, ...user }
      localStorage.setItem('auth-user', JSON.stringify(auth.value.user))
    }
  }

  // 检查是否已登录
  const isLoggedIn = () => {
    try {
      // 优先使用响应式数据
      if (auth.value?.token) {
        return true
      }

      // 如果响应式数据不可用，从localStorage读取
      const savedToken = localStorage.getItem('auth-token')
      console.log('isLoggedIn()调试: auth.value?.token=', !!auth.value?.token, ', savedToken=', !!savedToken)
      return !!savedToken
    } catch (error) {
      console.warn('检查登录状态时出错:', error)
      return false
    }
  }

  // 检查是否有权限
  const hasPermission = (permission: string) => {
    try {
      const permissions = auth.value?.permissions || []
      if (!permissions.length) return true // 如果没有配置权限，则认为有权限
      return permissions.includes(permission)
    } catch (error) {
      console.warn('检查权限时出错:', error)
      return false
    }
  }

  // 检查是否有角色
  const hasRole = (role: string) => {
    try {
      return auth.value?.user?.role === role
    } catch (error) {
      console.warn('检查角色时出错:', error)
      return false
    }
  }

  // 获取用户显示名称
  const displayName = () => {
    try {
      const user = auth.value?.user
      if (!user) return '未登录'
      return user.nickname || user.username || '未知用户'
    } catch (error) {
      console.warn('获取用户显示名称时出错:', error)
      return '未登录'
    }
  }

  // 获取用户角色名称
  const getUserRole = () => {
    try {
      const user = auth.value?.user
      if (!user) return '未知'

      switch (user.userType) {
        case 1: return '求职者'
        case 2: return 'HR'
        case 3: return '管理员'
        default: return '未知'
      }
    } catch (error) {
      console.warn('获取用户角色时出错:', error)
      return '未知'
    }
  }

  // 检查是否为管理员
  const isAdmin = () => {
    try {
      // 优先使用响应式数据
      const user = auth.value?.user
      if (user && user.userType === 3) {
        return true
      }

      // 如果响应式数据不可用，从localStorage读取
      const savedUser = localStorage.getItem('auth-user')
      if (savedUser) {
        const userData = JSON.parse(savedUser)
        return userData.userType === 3
      }

      return false
    } catch (error) {
      console.warn('检查管理员权限时出错:', error)
      return false
    }
  }

  return {
    auth,
    initAuth,
    login,
    logout,
    updateUser,
    isLoggedIn,
    hasPermission,
    hasRole,
    displayName,
    getUserRole,
    isAdmin
  }
})