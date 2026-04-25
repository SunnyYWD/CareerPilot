import axios, { type AxiosInstance, type AxiosRequestConfig, type AxiosResponse } from 'axios'
import { useUserStore } from '@/store/user'

// API响应接口
export interface ApiResponse<T = any> {
  code: number
  message: string
  data: T
}

// ==================== 服务配置 ====================
// 注意：后端实际上是单体应用，所有服务都在8080端口
const baseURL = import.meta.env.VITE_API_BASE_URL || 'http://localhost:8080/smarthire/api'

const SERVICE_CONFIGS = {
  main: {
    baseURL,
    timeout: 10000
  },
  auth: {
    baseURL,
    timeout: 10000
  },
  admin: {
    baseURL,
    timeout: 10000
  }
}

// ==================== 创建axios实例 ====================
function createAxiosInstance(baseURL: string, timeout: number): AxiosInstance {
  const instance = axios.create({
    baseURL,
    timeout,
    headers: {
      'Content-Type': 'application/json'
    }
  })

  // 请求拦截器 - 添加Token
  instance.interceptors.request.use(
    (config: AxiosRequestConfig) => {
      const userStore = useUserStore()
      const token = userStore.auth.token

      if (token && config.headers) {
        config.headers.Authorization = `Bearer ${token}`
        console.log('📤 发送请求:', config.baseURL + config.url)
        console.log('- Authorization:', config.headers.Authorization.substring(0, 80) + '...')
      }

      return config
    },
    (error) => {
      return Promise.reject(error)
    }
  )

  // 响应拦截器 - 处理响应和错误
  instance.interceptors.response.use(
    (response: AxiosResponse<ApiResponse>) => {
      const { code, message, data } = response.data

      console.log('📥 响应拦截器 - 完整响应:', {
        url: response.config.url,
        status: response.status,
        code,
        message,
        hasData: !!data
      })

      // 请求成功
      if (code === 0) {
        return data
      }

      // 请求失败 - 记录详细信息
      console.error('❌ 后端返回非0 code:', {
        code,
        message,
        data,
        url: response.config.url
      })
      return Promise.reject(new Error(message))
    },
    async (error) => {
      const { response, config } = error

      // 网络错误
      if (!response) {
        return Promise.reject(new Error('网络错误，请检查网络连接'))
      }

      const { status, data } = response

      // Token过期或无效
      if (status === 401 || data?.code === 1012) {
        console.warn('⚠️ 收到401错误或code===1012, 详细信息:')
        console.log('- 请求URL:', config?.url)
        console.log('- 响应状态:', status)
        console.log('- 响应code:', data?.code)
        console.log('- 响应message:', data?.message)

        const userStore = useUserStore()

        // 尝试刷新token
        try {
          const refreshToken = localStorage.getItem('refresh-token')
          console.log('- refreshToken存在:', !!refreshToken)

          if (refreshToken) {
            // 使用authRequest刷新token
            const res = await authRequest.post('/user-auth/refresh-token', {
              refreshToken
            })

            if (res.data.code === 0) {
              console.log('✅ token刷新成功')
              const { accessToken, refreshToken: newRefreshToken } = res.data.data

              // 从新token中解析用户信息
              try {
                const tokenPayload = JSON.parse(atob(accessToken.split('.')[1]))
                console.log('从刷新的token中解析用户数据:', tokenPayload)

                const userData = {
                  id: tokenPayload.claims?.id || 0,
                  username: tokenPayload.claims?.username || 'unknown',
                  userType: tokenPayload.claims?.userType || 1,
                  status: 1
                }

                console.log('解析到的用户数据:', userData)

                // 保存新token和用户数据
                userStore.login(accessToken, userData, userStore.auth.permissions)
                localStorage.setItem('refresh-token', newRefreshToken)
              } catch (parseError) {
                console.error('解析刷新token失败:', parseError)
                userStore.login(accessToken, userStore.auth.user!, userStore.auth.permissions)
                localStorage.setItem('refresh-token', newRefreshToken)
              }

              // 重新发送原请求
              if (config && config.headers) {
                config.headers.Authorization = `Bearer ${accessToken}`
                return instance(config)
              }
            } else {
              console.error('❌ token刷新失败:', res.data.message)
            }
          }
        } catch (refreshError) {
          console.error('❌ 刷新token时发生异常:', refreshError)
        }

        // 刷新失败，清除登录状态并跳转到登录页
        console.warn('🚨 token刷新失败，清除登录状态')
        userStore.logout()
        localStorage.removeItem('refresh-token')
        window.location.href = '/login'
        return Promise.reject(new Error('登录已过期，请重新登录'))
      }

      // 其他错误
      const errorMessage = data?.message || '请求失败'
      return Promise.reject(new Error(errorMessage))
    }
  )

  return instance
}

// ==================== 导出不同服务的axios实例 ====================
export const mainRequest = createAxiosInstance(
  SERVICE_CONFIGS.main.baseURL,
  SERVICE_CONFIGS.main.timeout
)

export const authRequest = createAxiosInstance(
  SERVICE_CONFIGS.auth.baseURL,
  SERVICE_CONFIGS.auth.timeout
)

export const adminRequest = createAxiosInstance(
  SERVICE_CONFIGS.admin.baseURL,
  SERVICE_CONFIGS.admin.timeout
)

// 默认导出主服务实例（向后兼容）
export default mainRequest