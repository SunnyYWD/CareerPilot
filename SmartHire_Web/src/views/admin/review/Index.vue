<template>
  <div class="review-page">
    <!-- 页面头部 -->
    <div class="page-header">
      <div class="header-content">
        <h1 class="page-title">招聘审核</h1>
        <p class="page-description">审核用户发布的招聘职位，确保信息准确合规</p>
      </div>
    </div>

    <!-- 状态筛选标签页 -->
    <NCard :bordered="false" class="filter-card">
      <NTabs v-model:value="activeTab" type="segment" animated>
        <NTabPane
          :name="tab.value"
          v-for="tab in statusTabs"
          :key="tab.value"
          :tab="() => tab.label"
        >
          <div class="tab-content">
            <div class="tab-header">
              <span class="tab-description">{{ tab.description }}</span>
              <div class="tab-count">
                <NTag :type="tab.type" size="small">{{ tab.count }}</NTag>
              </div>
            </div>
          </div>
        </NTabPane>
      </NTabs>
    </NCard>

    <!-- 搜索和筛选 -->
    <NCard :bordered="false" class="search-card">
      <div class="search-section">
        <div class="search-input">
          <NInput
            v-model:value="searchKeyword"
            placeholder="搜索职位名称、公司名称"
            clearable
            @update:value="handleSearch"
          >
            <template #prefix>
              <span class="search-icon">🔍</span>
            </template>
          </NInput>
        </div>
        <div class="search-actions">
          <NButton @click="handleRefresh">
            <template #icon>🔄</template>
            刷新
          </NButton>
        </div>
      </div>
    </NCard>

    <!-- 职位列表 -->
    <NCard :bordered="false" class="list-card">
      <div class="list-header">
        <span class="list-title">{{ currentTab.title }}</span>
        <div class="list-actions">
          <span class="total-count">共 {{ filteredJobs.length }} 条记录</span>
        </div>
      </div>

      <div class="job-list">
        <div
          v-for="job in filteredJobs"
          :key="job.id"
          class="job-item"
          @click="viewJobDetail(job)"
        >
          <div class="job-header">
            <div class="job-title">
              <h3>{{ job.title }}</h3>
              <NTag :type="getStatusType(job.status)" size="small">
                {{ getStatusText(job.status) }}
              </NTag>
            </div>
            <div class="job-actions">
              <NButton
                v-if="job.status === 'pending'"
                size="small"
                type="success"
                @click.stop="handleApprove(job)"
              >
                通过
              </NButton>
              <NButton
                v-if="job.status === 'pending'"
                size="small"
                type="warning"
                @click.stop="handleModify(job)"
              >
                要求修改
              </NButton>
              <NButton
                v-if="job.status === 'pending'"
                size="small"
                type="error"
                @click.stop="handleReject(job)"
              >
                拒绝
              </NButton>
              <NButton
                v-if="job.status === 'approved'"
                size="small"
                type="error"
                @click.stop="handleForceOffline(job)"
              >
                强制下线
              </NButton>
            </div>
          </div>

          <div class="job-company">
            <div class="company-info">
              <span class="company-name">{{ job.company }}</span>
              <span class="company-location">📍 {{ job.location }}</span>
            </div>
          </div>

          <div class="job-meta">
            <div class="meta-left">
              <span class="salary">💰 {{ job.salary }}</span>
              <span class="experience">🎓 {{ job.experience }}</span>
              <span class="education">🎓 {{ job.education }}</span>
            </div>
            <div class="meta-right">
              <span class="publisher">发布者：{{ job.publisher }}</span>
              <span class="time">发布时间：{{ formatTime(job.createTime) }}</span>
            </div>
          </div>

          <div class="job-tags" v-if="job.tags && job.tags.length > 0">
            <NTag
              v-for="tag in job.tags"
              :key="tag"
              size="small"
              type="info"
              class="job-tag"
            >
              {{ tag }}
            </NTag>
          </div>

          <div class="job-description" v-if="job.description">
            <p class="description-text">{{ job.description }}</p>
          </div>
        </div>
      </div>

      <!-- 空状态 -->
      <div v-if="filteredJobs.length === 0" class="empty-state">
        <div class="empty-icon">📋</div>
        <h3 class="empty-title">暂无{{ currentTab.emptyText }}</h3>
        <p class="empty-description">{{ currentTab.emptyDesc }}</p>
      </div>
    </NCard>

    <!-- 岗位详情弹窗 -->
    <NModal v-model:show="showDetailModal" :mask-closable="false">
      <NCard
        style="max-width: 900px !important; max-height: 85vh !important; overflow-y: auto !important; border-radius: 16px !important; box-shadow: 0 20px 60px rgba(0, 0, 0, 0.15) !important;"
        title="岗位详情"
        :bordered="false"
        size="huge"
        role="dialog"
        aria-modal
      >
        <template #header-extra>
          <NButton
            quaternary
            circle
            @click="showDetailModal = false"
            style="width: 36px !important; height: 36px !important; border-radius: 50% !important; transition: all 0.3s ease !important;"
          >
            <template #icon>
              <span class="close-icon" style="font-size: 20px !important; color: #666 !important; line-height: 1 !important; display: block !important;">×</span>
            </template>
          </NButton>
        </template>

        <div v-if="selectedJob" class="job-detail" style="padding: 0 !important; margin: 0 !important;">
          <!-- 岗位基本信息 -->
          <div class="detail-header" style="display: flex !important; align-items: center !important; gap: 20px !important; padding: 32px !important; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%) !important; border-radius: 12px !important; margin: 0 0 32px 0 !important; color: white !important; position: relative !important; overflow: hidden !important;">
            <div class="detail-basic-info" style="flex: 1 !important; position: relative !important; z-index: 2 !important;">
              <h3 class="detail-title" style="font-size: 28px !important; font-weight: 700 !important; margin: 0 0 16px 0 !important; color: white !important; line-height: 1.3 !important; text-shadow: 0 2px 4px rgba(0,0,0,0.1) !important;">{{ selectedJob.title }}</h3>
              <div class="detail-tags" style="display: flex !important; gap: 12px !important; flex-wrap: wrap !important;">
                <NTag :type="getStatusType(selectedJob.status)" size="medium" style="background: rgba(255, 255, 255, 0.25) !important; border: 1px solid rgba(255, 255, 255, 0.35) !important; color: white !important; backdrop-filter: blur(10px) !important; font-weight: 600 !important; padding: 6px 16px !important; border-radius: 20px !important;">
                  {{ getStatusText(selectedJob.status) }}
                </NTag>
              </div>
            </div>
          </div>

          <!-- 详细信息网格 -->
          <div class="detail-info-grid" style="display: grid !important; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)) !important; gap: 24px !important; margin-bottom: 32px !important;">
            <div class="info-card" style="background: #ffffff !important; border: 1px solid #e8e8e8 !important; border-radius: 16px !important; padding: 24px !important; transition: all 0.3s ease !important; box-shadow: 0 4px 12px rgba(0, 0, 0, 0.05) !important;">
              <div class="info-card-header" style="display: flex !important; align-items: center !important; gap: 12px !important; margin-bottom: 20px !important;">
                <span class="info-icon" style="font-size: 24px !important; width: 48px !important; height: 48px !important; background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%) !important; border-radius: 12px !important; display: flex !important; align-items: center !important; justify-content: center !important; flex-shrink: 0 !important;">🏢</span>
                <h4 style="font-size: 18px !important; font-weight: 700 !important; color: #1a1a1a !important; margin: 0 !important; line-height: 1.3 !important;">公司信息</h4>
              </div>
              <div class="info-content">
                <div class="info-item" style="display: flex !important; justify-content: space-between !important; align-items: center !important; padding: 16px 0 !important; border-bottom: 1px solid #f0f0f0 !important;">
                  <label style="font-size: 14px !important; color: #6b7280 !important; font-weight: 600 !important; flex-shrink: 0 !important; margin-right: 16px !important; text-transform: uppercase !important; letter-spacing: 0.5px !important;">公司名称</label>
                  <span style="font-size: 16px !important; color: #1a1a1a !important; font-weight: 600 !important; text-align: right !important; word-break: break-all !important;">{{ selectedJob.company }}</span>
                </div>
                <div class="info-item" style="display: flex !important; justify-content: space-between !important; align-items: center !important; padding: 16px 0 !important; border-bottom: 1px solid #f0f0f0 !important;">
                  <label style="font-size: 14px !important; color: #6b7280 !important; font-weight: 600 !important; flex-shrink: 0 !important; margin-right: 16px !important; text-transform: uppercase !important; letter-spacing: 0.5px !important;">工作地点</label>
                  <span style="font-size: 16px !important; color: #1a1a1a !important; font-weight: 600 !important; text-align: right !important; word-break: break-all !important;">📍 {{ selectedJob.location }}</span>
                </div>
              </div>
            </div>

            <div class="info-card" style="background: #ffffff !important; border: 1px solid #e8e8e8 !important; border-radius: 16px !important; padding: 24px !important; transition: all 0.3s ease !important; box-shadow: 0 4px 12px rgba(0, 0, 0, 0.05) !important;">
              <div class="info-card-header" style="display: flex !important; align-items: center !important; gap: 12px !important; margin-bottom: 20px !important;">
                <span class="info-icon" style="font-size: 24px !important; width: 48px !important; height: 48px !important; background: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%) !important; border-radius: 12px !important; display: flex !important; align-items: center !important; justify-content: center !important; flex-shrink: 0 !important;">💰</span>
                <h4 style="font-size: 18px !important; font-weight: 700 !important; color: #1a1a1a !important; margin: 0 !important; line-height: 1.3 !important;">薪资待遇</h4>
              </div>
              <div class="info-content">
                <div class="info-item" style="display: flex !important; justify-content: space-between !important; align-items: center !important; padding: 16px 0 !important; border-bottom: 1px solid #f0f0f0 !important;">
                  <label style="font-size: 14px !important; color: #6b7280 !important; font-weight: 600 !important; flex-shrink: 0 !important; margin-right: 16px !important; text-transform: uppercase !important; letter-spacing: 0.5px !important;">薪资范围</label>
                  <span style="font-size: 16px !important; color: #1a1a1a !important; font-weight: 600 !important; text-align: right !important; word-break: break-all !important;">{{ selectedJob.salary }}</span>
                </div>
                <div class="info-item" style="display: flex !important; justify-content: space-between !important; align-items: center !important; padding: 16px 0 !important; border-bottom: 1px solid #f0f0f0 !important;">
                  <label style="font-size: 14px !important; color: #6b7280 !important; font-weight: 600 !important; flex-shrink: 0 !important; margin-right: 16px !important; text-transform: uppercase !important; letter-spacing: 0.5px !important;">经验要求</label>
                  <span style="font-size: 16px !important; color: #1a1a1a !important; font-weight: 600 !important; text-align: right !important; word-break: break-all !important;">{{ selectedJob.experience }}</span>
                </div>
                <div class="info-item" style="display: flex !important; justify-content: space-between !important; align-items: center !important; padding: 16px 0 !important;">
                  <label style="font-size: 14px !important; color: #6b7280 !important; font-weight: 600 !important; flex-shrink: 0 !important; margin-right: 16px !important; text-transform: uppercase !important; letter-spacing: 0.5px !important;">学历要求</label>
                  <span style="font-size: 16px !important; color: #1a1a1a !important; font-weight: 600 !important; text-align: right !important; word-break: break-all !important;">{{ selectedJob.education }}</span>
                </div>
              </div>
            </div>

            <div class="info-card" style="background: #ffffff !important; border: 1px solid #e8e8e8 !important; border-radius: 16px !important; padding: 24px !important; transition: all 0.3s ease !important; box-shadow: 0 4px 12px rgba(0, 0, 0, 0.05) !important;">
              <div class="info-card-header" style="display: flex !important; align-items: center !important; gap: 12px !important; margin-bottom: 20px !important;">
                <span class="info-icon" style="font-size: 24px !important; width: 48px !important; height: 48px !important; background: linear-gradient(135deg, #fa709a 0%, #fee140 100%) !important; border-radius: 12px !important; display: flex !important; align-items: center !important; justify-content: center !important; flex-shrink: 0 !important;">👤</span>
                <h4 style="font-size: 18px !important; font-weight: 700 !important; color: #1a1a1a !important; margin: 0 !important; line-height: 1.3 !important;">发布信息</h4>
              </div>
              <div class="info-content">
                <div class="info-item" style="display: flex !important; justify-content: space-between !important; align-items: center !important; padding: 16px 0 !important; border-bottom: 1px solid #f0f0f0 !important;">
                  <label style="font-size: 14px !important; color: #6b7280 !important; font-weight: 600 !important; flex-shrink: 0 !important; margin-right: 16px !important; text-transform: uppercase !important; letter-spacing: 0.5px !important;">发布者</label>
                  <span style="font-size: 16px !important; color: #1a1a1a !important; font-weight: 600 !important; text-align: right !important; word-break: break-all !important;">{{ selectedJob.publisher }}</span>
                </div>
                <div class="info-item" style="display: flex !important; justify-content: space-between !important; align-items: center !important; padding: 16px 0 !important;">
                  <label style="font-size: 14px !important; color: #6b7280 !important; font-weight: 600 !important; flex-shrink: 0 !important; margin-right: 16px !important; text-transform: uppercase !important; letter-spacing: 0.5px !important;">发布时间</label>
                  <span style="font-size: 16px !important; color: #1a1a1a !important; font-weight: 600 !important; text-align: right !important; word-break: break-all !important;">{{ formatTime(selectedJob.createTime) }}</span>
                </div>
              </div>
            </div>
          </div>

          <!-- 岗位描述 -->
          <div class="info-card full-width" style="background: #ffffff !important; border: 1px solid #e8e8e8 !important; border-radius: 16px !important; padding: 24px !important; margin-bottom: 32px !important; transition: all 0.3s ease !important; box-shadow: 0 4px 12px rgba(0, 0, 0, 0.05) !important;">
            <div class="info-card-header" style="display: flex !important; align-items: center !important; gap: 12px !important; margin-bottom: 20px !important;">
              <span class="info-icon" style="font-size: 24px !important; width: 48px !important; height: 48px !important; background: linear-gradient(135deg, #a8edea 0%, #fed6e3 100%) !important; border-radius: 12px !important; display: flex !important; align-items: center !important; justify-content: center !important; flex-shrink: 0 !important;">📝</span>
              <h4 style="font-size: 18px !important; font-weight: 700 !important; color: #1a1a1a !important; margin: 0 !important; line-height: 1.3 !important;">岗位描述</h4>
            </div>
            <div class="info-content">
              <div class="description-full" style="font-size: 16px !important; color: #374151 !important; line-height: 1.7 !important; white-space: pre-wrap !important; word-break: break-word !important; background: #fafbfc !important; padding: 20px !important; border-radius: 8px !important; border: 1px solid #f0f2f5 !important;">
                {{ selectedJob.description }}
              </div>
            </div>
          </div>

          <!-- 技能标签 -->
          <div class="info-card full-width" v-if="selectedJob.tags && selectedJob.tags.length > 0" style="background: #ffffff !important; border: 1px solid #e8e8e8 !important; border-radius: 16px !important; padding: 24px !important; margin-bottom: 32px !important; transition: all 0.3s ease !important; box-shadow: 0 4px 12px rgba(0, 0, 0, 0.05) !important;">
            <div class="info-card-header" style="display: flex !important; align-items: center !important; gap: 12px !important; margin-bottom: 20px !important;">
              <span class="info-icon" style="font-size: 24px !important; width: 48px !important; height: 48px !important; background: linear-gradient(135deg, #ffecd2 0%, #fcb69f 100%) !important; border-radius: 12px !important; display: flex !important; align-items: center !important; justify-content: center !important; flex-shrink: 0 !important;">🏷️</span>
              <h4 style="font-size: 18px !important; font-weight: 700 !important; color: #1a1a1a !important; margin: 0 !important; line-height: 1.3 !important;">技能标签</h4>
            </div>
            <div class="info-content">
              <div class="tags-full" style="display: flex !important; gap: 12px !important; flex-wrap: wrap !important;">
                <NTag
                  v-for="tag in selectedJob.tags"
                  :key="tag"
                  size="medium"
                  type="info"
                  class="detail-tag"
                  style="font-size: 14px !important; font-weight: 600 !important; padding: 6px 16px !important; border-radius: 20px !important; background: rgba(32, 128, 240, 0.1) !important; border-color: rgba(32, 128, 240, 0.2) !important;"
                >
                  {{ tag }}
                </NTag>
              </div>
            </div>
          </div>
        </div>

        <template #footer>
          <div class="modal-actions" style="display: flex !important; justify-content: space-between !important; align-items: center !important; gap: 16px !important; padding-top: 24px !important; border-top: 1px solid #f0f2f5 !important;">
            <NButton @click="showDetailModal = false" style="padding: 12px 24px !important; height: auto !important; font-size: 16px !important; font-weight: 500 !important; border-radius: 8px !important;">关闭</NButton>
            <div v-if="selectedJob" class="action-buttons" style="display: flex !important; gap: 12px !important;">
              <template v-if="selectedJob.status === 'pending'">
                <NButton
                  type="success"
                  @click="handleApprove(selectedJob)"
                  style="padding: 12px 24px !important; height: auto !important; font-size: 16px !important; font-weight: 600 !important; border-radius: 8px !important;"
                >
                  通过
                </NButton>
                <NButton
                  type="warning"
                  @click="handleModify(selectedJob)"
                  style="padding: 12px 24px !important; height: auto !important; font-size: 16px !important; font-weight: 600 !important; border-radius: 8px !important;"
                >
                  要求修改
                </NButton>
                <NButton
                  type="error"
                  @click="handleReject(selectedJob)"
                  style="padding: 12px 24px !important; height: auto !important; font-size: 16px !important; font-weight: 600 !important; border-radius: 8px !important;"
                >
                  拒绝
                </NButton>
              </template>
              <NButton
                v-if="selectedJob.status === 'approved'"
                type="error"
                @click="handleForceOffline(selectedJob)"
                style="padding: 12px 24px !important; height: auto !important; font-size: 16px !important; font-weight: 600 !important; border-radius: 8px !important;"
              >
                强制下线
              </NButton>
            </div>
          </div>
        </template>
      </NCard>
    </NModal>

    <!-- 审核操作弹窗 -->
    <NModal v-model:show="showActionModal" :mask-closable="false">
      <NCard
        style="max-width: 600px"
        title="审核确认"
        :bordered="false"
        size="huge"
        role="dialog"
        aria-modal
      >
        <template #header-extra>
          <NButton
            quaternary
            circle
            @click="showActionModal = false"
          >
            <template #icon>
              <span class="close-icon">×</span>
            </template>
          </NButton>
        </template>

        <div class="modal-content">
          <div class="job-preview">
            <h4>{{ currentJob?.title }}</h4>
            <p class="preview-company">{{ currentJob?.company }}</p>
          </div>

          <div class="action-form" v-if="actionType === 'reject' || actionType === 'modify' || actionType === 'offline'">
            <NForm
              ref="actionFormRef"
              :model="actionForm"
              label-placement="left"
              label-width="auto"
            >
              <NFormItem
                :label="actionType === 'offline' ? '下线原因' : '审核意见'"
                :rule="[
                  { required: true, message: actionType === 'offline' ? '请输入下线原因' : '请输入审核意见', trigger: ['blur'] }
                ]"
              >
                <NInput
                  v-model:value="actionForm.reason"
                  type="textarea"
                  :placeholder="actionType === 'offline' ? '请输入强制下线的原因' : '请输入审核意见'"
                  :rows="4"
                />
              </NFormItem>

              <NFormItem>
                <NCheckbox v-model:checked="actionForm.sendNotification">
                  发送通知给HR
                </NCheckbox>
              </NFormItem>

              <!-- 通知编辑区域 -->
              <template v-if="actionForm.sendNotification">
                <NFormItem label="通知标题">
                  <NInput
                    v-model:value="actionForm.notificationTitle"
                    placeholder="请输入通知标题"
                    maxlength="100"
                    show-count
                  />
                </NFormItem>

                <NFormItem label="通知内容">
                  <NInput
                    v-model:value="actionForm.notificationContent"
                    type="textarea"
                    placeholder="请输入通知内容"
                    :rows="4"
                    maxlength="500"
                    show-count
                  />
                </NFormItem>
              </template>
            </NForm>
          </div>

          <div class="action-message" v-else>
            <p>确定要{{ actionText }}这条职位吗？</p>
          </div>
        </div>

        <template #footer>
          <div class="modal-actions">
            <NButton @click="showActionModal = false">取消</NButton>
            <NButton
              type="primary"
              :loading="actionLoading"
              @click="confirmAction"
              :disabled="(actionType === 'reject' || actionType === 'modify' || actionType === 'offline') && !actionForm.reason.trim()"
            >
              {{ actionText }}
            </NButton>
          </div>
        </template>
      </NCard>
    </NModal>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
import {
  NCard,
  NTabs,
  NTabPane,
  NInput,
  NButton,
  NTag,
  NModal,
  NForm,
  NFormItem,
  NCheckbox,
  useMessage
} from 'naive-ui'
import type { FormInst } from 'naive-ui'
import dayjs from 'dayjs'
import {
  getJobAuditList,
  approveJob,
  rejectJob,
  modifyJob,
  forceOfflineJob,
  getJobAuditStats,
  type Job,
  type JobAuditQueryParams,
  type JobAuditParams
} from '@/api/job'
import { sendNotificationWithRelated } from '@/api/notification'

interface StatusTab {
  value: string
  label: string
  description: string
  count: number | null
  type: 'info' | 'success' | 'warning' | 'error'
  emptyText: string
  emptyDesc: string
  title?: string  // 可选的title属性
}

const message = useMessage()

// 岗位详情弹窗状态
const showDetailModal = ref(false)
const selectedJob = ref<Job | null>(null)

// 状态标签页
const activeTab = ref('pending')
const statusTabs = ref<StatusTab[]>([
  {
    value: 'pending',
    label: '待审核',
    description: '需要审核的职位',
    count: null,
    type: 'info',
    emptyText: '待审核职位',
    emptyDesc: '当前没有需要审核的职位'
  },
  {
    value: 'approved',
    label: '已通过',
    description: '已通过审核的职位',
    count: null,
    type: 'success',
    emptyText: '已通过职位',
    emptyDesc: '当前没有已通过的职位'
  },
  {
    value: 'rejected',
    label: '已拒绝',
    description: '被拒绝的职位',
    count: null,
    type: 'error',
    emptyText: '已拒绝职位',
    emptyDesc: '当前没有已拒绝的职位'
  },
  {
    value: 'modified',
    label: '需修改',
    description: '需要修改的职位',
    count: null,
    type: 'warning',
    emptyText: '需修改职位',
    emptyDesc: '当前没有需要修改的职位'
  }
])

// 状态数据
const jobsData = ref<Job[]>([])

// 分页参数
const pagination = ref({
  current: 1,
  size: 20,
  total: 0
})

// 加载状态
const loading = ref(false)

// 搜索和筛选
const searchKeyword = ref('')
const actionType = ref<'approve' | 'reject' | 'modify' | 'offline'>('approve')
const actionText = computed(() => {
  const textMap = {
    approve: '通过',
    reject: '拒绝',
    modify: '要求修改',
    offline: '强制下线'
  }
  return textMap[actionType.value] || '操作'
})

// 审核弹窗
const showActionModal = ref(false)
const actionLoading = ref(false)
const currentJob = ref<Job | null>(null)
const actionFormRef = ref<FormInst | null>(null)
const actionForm = ref({
  reason: '',
  sendNotification: false,
  notificationTitle: '',
  notificationContent: ''
})

// 计算属性
const currentTab = computed(() => statusTabs.value.find(tab => tab.value === activeTab.value)!)
const filteredJobs = computed(() => {
  let filtered = jobsData.value.filter(job => job.status === activeTab.value)

  if (searchKeyword.value.trim()) {
    const keyword = searchKeyword.value.toLowerCase()
    filtered = filtered.filter(job =>
      job.title.toLowerCase().includes(keyword) ||
      job.company.toLowerCase().includes(keyword) ||
      job.publisher.toLowerCase().includes(keyword)
    )
  }

  return filtered
})

// 获取当前标签页的标题
const getCurrentTabTitle = computed(() => {
  const tab = statusTabs.value.find(t => t.value === activeTab.value)
  return tab ? tab.label : '职位列表'
})

// 获取状态类型
const getStatusType = (status: string): 'info' | 'success' | 'warning' | 'error' => {
  const typeMap: Record<string, 'info' | 'success' | 'warning' | 'error'> = {
    pending: 'info',
    approved: 'success',
    rejected: 'error',
    modified: 'warning'
  }
  return typeMap[status] || 'info'
}

// 获取状态文本
const getStatusText = (status: string) => {
  const textMap: Record<string, string> = {
    pending: '待审核',
    approved: '已通过',
    rejected: '已拒绝',
    modified: '需修改'
  }
  return textMap[status] || status
}

// 格式化时间
const formatTime = (time: string) => {
  return dayjs(time).format('YYYY-MM-DD HH:mm')
}

// 搜索处理
const handleSearch = (value: string) => {
  searchKeyword.value = value
}

// 获取职位审核列表
const fetchJobs = async () => {
  loading.value = true
  try {
    const params: JobAuditQueryParams = {
      current: pagination.value.current,
      size: pagination.value.size,
      status: activeTab.value,
      keyword: searchKeyword.value.trim() || undefined
    }

    const response = await getJobAuditList(params)
    jobsData.value = response.records
    pagination.value.total = response.total
  } catch (error) {
    message.error('获取职位列表失败')
    console.error('获取职位列表失败:', error)
  } finally {
    loading.value = false
  }
}

// 刷新数据
const handleRefresh = () => {
  pagination.value.current = 1
  fetchJobs()
}

// 查看职位详情
const viewJobDetail = (job: Job) => {
  selectedJob.value = job
  showDetailModal.value = true
}

// 通过审核
const handleApprove = (job: Job) => {
  currentJob.value = job
  actionType.value = 'approve'
  showActionModal.value = true
}

// 拒绝审核
const handleReject = (job: Job) => {
  currentJob.value = job
  actionType.value = 'reject'
  actionForm.value = {
    reason: '',
    sendNotification: true,
    notificationTitle: '职位审核拒绝通知',
    notificationContent: `您好，您发布的职位《${job.title}》未通过审核。审核意见：请根据要求修改职位信息。如有疑问请联系客服。`
  }
  showActionModal.value = true
}

// 要求修改
const handleModify = (job: Job) => {
  currentJob.value = job
  actionType.value = 'modify'
  actionForm.value = {
    reason: '',
    sendNotification: true,
    notificationTitle: '职位审核修改通知',
    notificationContent: `您好，您发布的职位《${job.title}》需要修改。修改建议：请根据审核意见完善职位信息。修改后可重新提交审核。如有疑问请联系客服。`
  }
  showActionModal.value = true
}

// 强制下线
const handleForceOffline = (job: Job) => {
  currentJob.value = job
  actionType.value = 'offline'
  actionForm.value = {
    reason: '',
    sendNotification: true,
    notificationTitle: '职位下线通知',
    notificationContent: `您好，您发布的职位《${job.title}》已被管理员下线。下线原因：请管理员填写具体原因。如有疑问请联系客服。`
  }
  showActionModal.value = true
}

// 确认审核操作
const confirmAction = async () => {
  if (!currentJob.value) return

  actionLoading.value = true

  try {
    const params: JobAuditParams = {
      reason: actionForm.value.reason
    }

    if (actionType.value === 'approve') {
      await approveJob(currentJob.value.id)
      message.success('职位审核通过')
    } else if (actionType.value === 'reject') {
      await rejectJob(currentJob.value.id, params)
      message.warning(`职位已拒绝，原因：${actionForm.value.reason}`)

      // 如果选择发送通知，则发送拒绝通知
      if (actionForm.value.sendNotification && currentJob.value.hrUserId) {
        try {
          await sendNotificationWithRelated(
            currentJob.value.hrUserId, // HR的user_id
            4, // 职位下线类型
            actionForm.value.notificationTitle,
            actionForm.value.notificationContent,
            currentJob.value.id,
            'job'
          )
        } catch (notificationError: any) {
          console.error('发送拒绝通知失败:', notificationError)
        }
      }
    } else if (actionType.value === 'modify') {
      await modifyJob(currentJob.value.id, params)
      message.info(`已要求修改职位，建议：${actionForm.value.reason}`)

      // 如果选择发送通知，则发送修改通知
      if (actionForm.value.sendNotification && currentJob.value.hrUserId) {
        try {
          await sendNotificationWithRelated(
            currentJob.value.hrUserId, // HR的user_id
            4, // 职位下线类型
            actionForm.value.notificationTitle,
            actionForm.value.notificationContent,
            currentJob.value.id,
            'job'
          )
        } catch (notificationError: any) {
          console.error('发送修改通知失败:', notificationError)
        }
      }
    } else if (actionType.value === 'offline') {
      await forceOfflineJob(currentJob.value.id, params)
      message.warning(`职位已强制下线，原因：${actionForm.value.reason}`)

      // 如果选择发送通知，则发送下线通知
      if (actionForm.value.sendNotification && currentJob.value.hrUserId) {
        try {
          await sendNotificationWithRelated(
            currentJob.value.hrUserId, // HR的user_id
            4, // 职位下线类型
            actionForm.value.notificationTitle,
            actionForm.value.notificationContent,
            currentJob.value.id,
            'job'
          )
        } catch (notificationError: any) {
          console.error('发送下线通知失败:', notificationError)
        }
      }
    }

    showActionModal.value = false
    // 重新获取数据以更新列表和统计
    fetchJobs()
    updateStatusStats()
  } catch (error) {
    console.error('审核操作失败:', error)
    message.error('操作失败，请重试')
  } finally {
    actionLoading.value = false
  }
}

// 更新状态统计数据
const updateStatusStats = async () => {
  try {
    const stats = await getJobAuditStats()

    statusTabs.value.forEach(tab => {
      tab.count = stats[tab.value as keyof typeof stats] || 0
    })
  } catch (error) {
    console.error('获取统计数据失败:', error)
  }
}

// 页面初始化
onMounted(() => {
  fetchJobs()
  updateStatusStats()
})

// 监听标签页切换
watch(activeTab, () => {
  pagination.value.current = 1
  fetchJobs()
})

// 监听搜索
watch(searchKeyword, () => {
  pagination.value.current = 1
  fetchJobs()
})
</script>

<style scoped lang="scss">
.review-page {
  // 页面头部
  .page-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 32px;
    padding: 24px;
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    border-radius: 16px;
    color: white;

    .header-content {
      .page-title {
        font-size: 28px;
        font-weight: 600;
        margin: 0 0 8px 0;
      }

      .page-description {
        font-size: 16px;
        opacity: 0.9;
        margin: 0;
      }
    }
  }

  // 状态筛选卡片
  .filter-card {
    margin-bottom: 24px;

    .tab-content {
      padding: 16px 0;

      .tab-header {
        display: flex;
        justify-content: space-between;
        align-items: center;

        .tab-description {
          color: var(--text-secondary);
          font-size: 14px;
        }

        .tab-count {
          .n-tag {
            font-weight: 500;
          }
        }
      }
    }
  }

  // 搜索卡片
  .search-card {
    margin-bottom: 24px;

    .search-section {
      display: flex;
      gap: 16px;
      align-items: center;

      .search-input {
        flex: 1;

        .search-icon {
          color: var(--text-disabled);
        }
      }

      .search-actions {
        .n-button {
          min-width: 80px;
        }
      }
    }
  }

  // 职位列表卡片
  .list-card {
    .list-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 24px;
      padding: 20px 24px;
      background: var(--bg-secondary);
      border-radius: 8px;

      .list-title {
        font-size: 18px;
        font-weight: 600;
        color: var(--text-primary);
      }

      .total-count {
        font-size: 14px;
        color: var(--text-secondary);
      }
    }

    .job-list {
      .job-item {
        background: var(--bg-primary);
        border: 1px solid var(--border-color);
        border-radius: 12px;
        padding: 24px;
        margin-bottom: 16px;
        cursor: pointer;
        transition: all 0.3s ease;

        &:hover {
          transform: translateY(-2px);
          box-shadow: var(--shadow-md);
          border-color: var(--primary-color);
        }

        &:last-child {
          margin-bottom: 0;
        }

        .job-header {
          display: flex;
          justify-content: space-between;
          align-items: flex-start;
          margin-bottom: 12px;

          .job-title {
            display: flex;
            align-items: center;
            gap: 12px;

            h3 {
              margin: 0;
              font-size: 18px;
              font-weight: 600;
              color: var(--text-primary);
            }

            .n-tag {
              font-size: 12px;
            }
          }

          .job-actions {
            display: flex;
            gap: 8px;

            .n-button {
              min-width: 70px;
            }
          }
        }

        .job-company {
          margin-bottom: 12px;

          .company-info {
            display: flex;
            align-items: center;
            gap: 16px;

            .company-name {
              font-size: 16px;
              font-weight: 500;
              color: var(--text-primary);
            }

            .company-location {
              font-size: 14px;
              color: var(--text-secondary);
            }
          }
        }

        .job-meta {
          display: flex;
          justify-content: space-between;
          align-items: center;
          margin-bottom: 12px;

          .meta-left {
            display: flex;
            gap: 16px;

            .salary, .experience, .education {
              font-size: 14px;
              color: var(--text-secondary);
            }
          }

          .meta-right {
            display: flex;
            gap: 16px;

            .publisher, .time {
              font-size: 13px;
              color: var(--text-disabled);
            }
          }
        }

        .job-tags {
          display: flex;
          gap: 8px;
          margin-bottom: 12px;

          .job-tag {
            .n-tag {
              font-size: 12px;
              background: rgba(32, 128, 240, 0.1);
              border-color: rgba(32, 128, 240, 0.2);
            }
          }
        }

        .job-description {
          .description-text {
            margin: 0;
            font-size: 14px;
            color: var(--text-secondary);
            line-height: 1.5;
            display: -webkit-box;
            -webkit-line-clamp: 2;
            -webkit-box-orient: vertical;
            overflow: hidden;
          }
        }
      }
    }

    .empty-state {
      text-align: center;
      padding: 60px 24px;

      .empty-icon {
        font-size: 64px;
        margin-bottom: 16px;
        opacity: 0.5;
      }

      .empty-title {
        font-size: 18px;
        font-weight: 600;
        color: var(--text-primary);
        margin: 0 0 8px 0;
      }

      .empty-description {
        font-size: 14px;
        color: var(--text-secondary);
        margin: 0;
      }
    }
  }

  // 岗位详情弹窗
  .job-detail {
    // 头部区域：岗位基本信息
    .detail-header {
      display: flex;
      align-items: center;
      gap: 20px;
      padding: 24px;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      border-radius: 12px;
      margin-bottom: 24px;
      color: white;

      .detail-basic-info {
        flex: 1;

        .detail-title {
          font-size: 24px;
          font-weight: 600;
          margin: 0 0 12px 0;
          color: white;
        }

        .detail-tags {
          display: flex;
          gap: 8px;
          flex-wrap: wrap;

          .n-tag {
            background: rgba(255, 255, 255, 0.2);
            border: 1px solid rgba(255, 255, 255, 0.3);
            color: white;
            backdrop-filter: blur(10px);
          }
        }
      }
    }

    // 信息网格
    .detail-info-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
      gap: 20px;
      margin-bottom: 20px;

      .info-card {
        background: #ffffff;
        border: 1px solid #e8e8e8;
        border-radius: 12px;
        padding: 20px;
        transition: all 0.3s ease;

        &.full-width {
          grid-column: 1 / -1;
        }

        &:hover {
          transform: translateY(-2px);
          box-shadow: 0 8px 25px rgba(0, 0, 0, 0.1);
        }

        .info-card-header {
          display: flex;
          align-items: center;
          gap: 12px;
          margin-bottom: 16px;

          .info-icon {
            font-size: 20px;
          }

          h4 {
            font-size: 16px;
            font-weight: 600;
            color: #333333;
            margin: 0;
          }
        }

        .info-content {
          .info-item {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 12px 0;
            border-bottom: 1px solid #f0f0f0;

            &:last-child {
              border-bottom: none;
              padding-bottom: 0;
            }

            &:first-child {
              padding-top: 0;
            }

            label {
              font-size: 14px;
              color: #666666;
              font-weight: 500;
              flex-shrink: 0;
              margin-right: 16px;
            }

            span {
              font-size: 14px;
              color: #333333;
              font-weight: 500;
              text-align: right;
              word-break: break-all;
            }
          }

          .description-full {
            font-size: 14px;
            color: #333333;
            line-height: 1.6;
            white-space: pre-wrap;
            word-break: break-word;
          }

          .tags-full {
            display: flex;
            gap: 8px;
            flex-wrap: wrap;

            .detail-tag {
              font-size: 13px;
            }
          }
        }
      }
    }
  }

  // 审核操作弹窗
  .modal-content {
    .job-preview {
      margin-bottom: 24px;
      padding: 16px;
      background: var(--bg-secondary);
      border-radius: 8px;

      h4 {
        margin: 0 0 8px 0;
        font-size: 16px;
        font-weight: 600;
        color: var(--text-primary);
      }

      .preview-company {
        margin: 0;
        font-size: 14px;
        color: var(--text-secondary);
      }
    }

    .action-form {
      margin-bottom: 16px;
    }

    .action-message {
      text-align: center;
      padding: 16px;
      color: var(--text-secondary);
    }
  }

  .modal-actions {
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 12px;

    .action-buttons {
      display: flex;
      gap: 8px;
    }
  }
}

// 响应式设计
@media (max-width: 768px) {
  .review-page {
    .page-header {
      padding: 16px;

      .header-content {
        .page-title {
          font-size: 24px;
        }

        .page-description {
          font-size: 14px;
        }
      }
    }

    .search-section {
      flex-direction: column;
      gap: 12px;

      .search-actions {
        align-self: flex-end;
      }
    }

    .job-list {
      .job-item {
        padding: 16px;

        .job-header {
          flex-direction: column;
          gap: 12px;
          align-items: flex-start;

          .job-actions {
            width: 100%;
            justify-content: flex-end;
          }
        }

        .job-meta {
          flex-direction: column;
          align-items: flex-start;
          gap: 8px;

          .meta-left {
            gap: 12px;
          }

          .meta-right {
            gap: 12px;
          }
        }

        .job-tags {
          flex-wrap: wrap;
        }
      }
    }
  }
}
</style>