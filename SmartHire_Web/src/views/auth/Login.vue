<template>
  <div class="login-page">
    <div class="login-container">
      <!-- 左侧背景 -->
      <div class="login-bg">
        <div class="bg-content">
          <div class="logo-section">
            <div class="logo-emoji">💼</div>
            <h1 class="title">SmartHire</h1>
            <p class="subtitle">智能招聘管理平台</p>
            <p class="subtitle">管理员界面</p>
          </div>
        </div>
      </div>

      <!-- 右侧登录表单 -->
      <div class="login-form-container">
        <div class="login-form-wrapper">
          <div class="form-header">
            <h2 class="form-title">欢迎回来</h2>
            <p class="form-subtitle">请登录您的管理员账号</p>
          </div>

          <NForm
            ref="formRef"
            :model="formData"
            :rules="rules"
            size="large"
            class="login-form"
          >
            <NFormItem path="username" label="用户名">
              <NInput
                v-model:value="formData.username"
                placeholder="请输入用户名"
                :maxlength="50"
                clearable
                @keydown.enter="handleSubmit"
              >
                <template #prefix>
                  <span class="input-icon">👤</span>
                </template>
              </NInput>
            </NFormItem>

            <NFormItem path="password" label="密码">
              <NInput
                v-model:value="formData.password"
                type="password"
                placeholder="请输入密码"
                :maxlength="50"
                show-password-on="click"
                @keydown.enter="handleSubmit"
              >
                <template #prefix>
                  <span class="input-icon">🔒</span>
                </template>
              </NInput>
            </NFormItem>

            <NFormItem>
              <div class="form-options">
                <NCheckbox v-model:checked="rememberMe">
                  记住我
                </NCheckbox>
              </div>
            </NFormItem>

            <NFormItem>
              <NButton
                type="primary"
                size="large"
                :loading="loading"
                :disabled="!canSubmit"
                @click="handleSubmit"
                class="submit-btn"
              >
                登录
              </NButton>
            </NFormItem>
          </NForm>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { NForm, NFormItem, NInput, NButton, NCheckbox, FormInst, useMessage } from 'naive-ui'
import { login, type LoginParams } from '@/api/auth'
import { useUserStore } from '@/store/user'
import { useThemeStore } from '@/store/theme'
import { generatePermissionsByUserType } from '@/utils/userType'

const router = useRouter()
const route = useRoute()
const userStore = useUserStore()
const themeStore = useThemeStore()
const message = useMessage()

// 表单相关
const formRef = ref<FormInst | null>(null)
const loading = ref(false)
const rememberMe = ref(false)

const formData = ref({
  username: '',
  password: ''
})

// 表单验证规则
const rules = {
  username: [
    {
      required: true,
      message: '请输入用户名',
      trigger: ['input', 'blur']
    },
    {
      min: 3,
      max: 50,
      message: '用户名长度应在 3-50 个字符之间',
      trigger: ['input', 'blur']
    }
  ],
  password: [
    {
      required: true,
      message: '请输入密码',
      trigger: ['input', 'blur']
    },
    {
      min: 6,
      max: 50,
      message: '密码长度应在 6-50 个字符之间',
      trigger: ['input', 'blur']
    }
  ]
}

// 计算是否可以提交
const canSubmit = computed(() => {
  return formData.value.username.trim() && formData.value.password.trim() && !loading.value
})

// 初始化
onMounted(() => {
  // 初始化主题
  themeStore.initTheme()

  // 恢复记住的用户名
  const savedUsername = localStorage.getItem('remembered-username')
  if (savedUsername) {
    formData.value.username = savedUsername
    rememberMe.value = true
  }

  // 如果已经登录，直接跳转
  if (userStore.isLoggedIn()) {
    router.push('/dashboard')
  }
})

// 处理登录
const handleSubmit = async () => {
  if (!formRef.value) return

  try {
    await formRef.value.validate()
  } catch (error) {
    return
  }

  loading.value = true

  try {
    // 真实登录请求
    const loginParams: LoginParams = {
      username: formData.value.username,
      password: formData.value.password
    }

    const response = await login(loginParams)

    console.log('登录响应:', response)
    
    // ❌ 后端LoginResponseDTO不包含user字段，只有accessToken和refreshToken
    // ✅ 必须从JWT token的payload中解析用户信息
    let userData: any = null
    
    try {
      // 解析JWT token的payload部分
      const tokenPayload = JSON.parse(atob(response.accessToken.split('.')[1]))
      console.log('JWT token解析结果:', tokenPayload)

      // 根据token中的claims构建用户数据
      if (tokenPayload.claims) {
        userData = {
          id: tokenPayload.claims.id || 0,
          username: tokenPayload.claims.username || 'unknown',
          userType: tokenPayload.claims.userType || 1,
          status: 1
        }
        console.log('从token解析的用户数据:', userData)
        console.log('用户类型:', userData.userType, '(1=求职者, 2=HR, 3=管理员)')

        // 检查是否为管理员，如果不是则阻止登录
        if (userData.userType !== 3) {
          console.warn('❌ 非管理员用户尝试登录管理员界面:', userData.username)
          message.error('只有管理员才能登录管理员界面')
          loading.value = false
          return
        }
      } else {
        throw new Error('Token中没有claims字段')
      }
    } catch (error) {
      console.error('❌ 解析JWT token失败:', error)
      message.error('登录失败：无法解析用户信息')
      loading.value = false
      return
    }
    
    // 验证用户数据有效性
    if (!userData || !userData.username || userData.username === 'unknown') {
      console.error('❌ 用户数据无效:', userData)
      message.error('登录失败：用户信息无效')
      loading.value = false
      return
    }

    // 保存登录信息 - 根据userType动态生成权限
    const permissions = generatePermissionsByUserType(userData.userType)
    console.log('生成的权限列表:', permissions)

    userStore.login(response.accessToken, userData, permissions)

    // 如果是管理员，获取完整的用户信息（包括头像）
    if (userData.userType === 3) {
      try {
        console.log('✅ 管理员登录，调用getUserDetail接口获取头像信息...')
        console.log('✅ 用户ID:', userData.id)
        console.log('✅ API路径: /smarthire/api/admin/users/' + userData.id)

        // 直接调用现有的getUserDetail接口
        const apiResponse = await fetch('/smarthire/api/admin/users/' + userData.id, {
          method: 'GET',
          headers: {
            'Authorization': 'Bearer ' + response.accessToken,
            'Content-Type': 'application/json'
          }
        })

        console.log('✅ API响应状态:', apiResponse.status)

        if (apiResponse.ok) {
          const result = await apiResponse.json()
          console.log('✅ 获取到用户详细信息:', result)

          // 检查Result格式的响应结构
          if (result.success && result.data && result.data.avatarUrl) {
            // 更新用户store中的头像信息，同时兼容avatarUrl和avatar字段
            userStore.updateUser({
              avatarUrl: result.data.avatarUrl,
              avatar: result.data.avatarUrl // 兼容字段
            })
            console.log('✅ 管理员头像已更新:', result.data.avatarUrl)
          } else {
            console.log('ℹ️ 用户没有设置头像或头像为空')
          }
        } else {
          console.error('❌ 获取用户信息失败，状态码:', apiResponse.status)
          const errorText = await apiResponse.text()
          console.error('❌ 错误响应:', errorText)
        }
      } catch (error) {
        console.error('❌ 获取用户信息时发生异常:', error)
      }
    }
    
    // 保存 refreshToken（修复401错误后无法刷新的问题）
    if (response.refreshToken) {
      localStorage.setItem('refresh-token', response.refreshToken)
      console.log('✅ refreshToken 已保存')
    } else {
      console.warn('⚠️ 登录响应中没有 refreshToken')
    }

    console.log('登录后用户状态:', userStore.isLoggedIn())
    console.log('用户是否为管理员:', userStore.isAdmin())

    message.success('登录成功')

    // 处理记住我
    if (rememberMe.value) {
      localStorage.setItem('remembered-username', formData.value.username)
    } else {
      localStorage.removeItem('remembered-username')
    }

    // 跳转到目标页面
    const redirect = route.query.redirect as string
    router.push(redirect || '/dashboard')
  } catch (error: any) {
    console.error('=== 登录过程发生错误 ===')
    console.error('错误对象:', error)
    console.error('错误消息:', error.message)
    console.error('错误堆栈:', error.stack)
    console.error('=======================')
    message.error(error.message || '登录失败，请检查用户名和密码')
  } finally {
    loading.value = false
  }
}

</script>

<style scoped lang="scss">
.login-page {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(135deg, #ffffff 0%, #000000 100%);
  padding: 20px;
}

.login-container {
  display: flex;
  width: 100%;
  max-width: 1200px;
  min-height: 600px;
  background: white;
  border-radius: 12px;
  overflow: hidden;
  box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
}

.login-bg {
  flex: 1;
  background:  url('@/assets/images/login-bg.jpg') center/cover no-repeat;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 60px 40px;
  position: relative;
  overflow: hidden;

  &::before {
    content: '';
    position: absolute;
    top: -50%;
    right: -50%;
    width: 200%;
    height: 200%;
    background: radial-gradient(circle, rgba(255,255,255,0.1) 1px, transparent 1px);
    background-size: 20px 20px;
    animation: float 20s linear infinite;
  }

  @keyframes float {
    0% { transform: translate(0, 0) rotate(0deg); }
    100% { transform: translate(-50px, -50px) rotate(360deg); }
  }
}

.bg-content {
  position: relative;
  z-index: 1;
  text-align: center;
  color: white;
}

.logo-section {
  margin-bottom: 60px;

  .logo-emoji {
    font-size: 80px;
    margin-bottom: 20px;
  }

  .title {
    font-size: 36px;
    font-weight: 700;
    margin: 0 0 8px 0;
    color: #000000;
  }

  .subtitle {
    font-size: 18px;
    opacity: 0.9;
    margin: 0;
    color: #000000;
  }
}

.features {
  display: flex;
  gap: 30px;
}

.feature-item {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 8px;

  .feature-icon {
    font-size: 32px;
    margin-bottom: 4px;
  }

  .feature-text {
    font-size: 14px;
    opacity: 0.9;
  }
}

.login-form-container {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 40px;
  background: var(--bg-primary);
}

.login-form-wrapper {
  width: 100%;
  max-width: 400px;
}

.form-header {
  text-align: center;
  margin-bottom: 40px;

  .form-title {
    font-size: 28px;
    font-weight: 600;
    color: var(--text-primary);
    margin: 0 0 8px 0;
  }

  .form-subtitle {
    font-size: 16px;
    color: var(--text-secondary);
    margin: 0;
  }
}

.login-form {
  .input-icon {
    color: var(--text-disabled);
  }

  .form-options {
    display: flex;
    justify-content: space-between;
    align-items: center;
    width: 100%;
  }

  .submit-btn {
    width: 100%;
    height: 48px;
    font-size: 16px;
    font-weight: 500;
  }
}

.form-footer {
  text-align: center;
  margin-top: 24px;

  .footer-text {
    font-size: 14px;
    color: var(--text-secondary);
    margin: 0;
  }
}

// 响应式设计
@media (max-width: 768px) {
  .login-container {
    flex-direction: column;
    max-width: 400px;
  }

  .login-bg {
    padding: 40px 20px;
    min-height: 200px;

    .features {
      gap: 20px;
    }

    .feature-item {
      .feature-icon {
        font-size: 24px;
      }

      .feature-text {
        font-size: 12px;
      }
    }
  }

  .logo-section {
    margin-bottom: 30px;

    .logo-emoji {
      font-size: 60px;
    }

    .title {
      font-size: 28px;
    }

    .subtitle {
      font-size: 16px;
    }
  }

  .login-form-container {
    padding: 30px 20px;
  }
}
</style>