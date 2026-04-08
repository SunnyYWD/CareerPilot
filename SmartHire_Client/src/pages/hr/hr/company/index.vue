<template>
  <view class="company-page">
    <view class="card overview-card">
      <view class="overview-label">企业资料</view>
      <view class="overview-title">{{ form.companyName || hrStore.companyName || '暂未填写企业名称' }}</view>
      <view class="overview-meta">
        <text>{{ selectedScaleLabel }}</text>
        <text>·</text>
        <text>{{ selectedFinancingLabel }}</text>
        <text v-if="form.industry">·</text>
        <text v-if="form.industry">{{ form.industry }}</text>
      </view>
    </view>

    <view v-if="loading" class="card status-card">
      <text class="status-text">加载中...</text>
    </view>

    <view v-else-if="!companyId" class="card status-card">
      <text class="status-text">当前账号尚未关联企业，暂时无法编辑企业资料。</text>
    </view>

    <template v-else>
      <view class="card">
        <view class="section-title">基础资料</view>

        <view class="form-item">
          <text class="label">企业名称</text>
          <input v-model="form.companyName" placeholder="请输入企业名称" />
        </view>

        <view class="form-item">
          <text class="label">行业方向</text>
          <input v-model="form.industry" placeholder="如：互联网 / 企业服务" />
        </view>

        <view class="form-item">
          <text class="label">公司规模</text>
          <picker mode="selector" :range="companyScaleOptions" range-key="label" :value="companyScaleIndex" @change="onCompanyScaleChange">
            <view class="picker-field">{{ selectedScaleLabel }}</view>
          </picker>
        </view>

        <view class="form-item">
          <text class="label">融资阶段</text>
          <picker mode="selector" :range="financingStageOptions" range-key="label" :value="financingStageIndex" @change="onFinancingStageChange">
            <view class="picker-field">{{ selectedFinancingLabel }}</view>
          </picker>
        </view>

        <view class="form-item">
          <text class="label">成立时间</text>
          <picker mode="date" :value="form.companyCreatedAt" @change="onDateChange">
            <view class="picker-field">{{ form.companyCreatedAt || '请选择成立时间' }}</view>
          </picker>
        </view>

        <view class="form-item">
          <text class="label">注册资本</text>
          <input v-model="form.registeredCapital" type="number" placeholder="请输入注册资本，单位万元" />
        </view>

        <view class="form-item">
          <text class="label">官方网站</text>
          <input v-model="form.website" placeholder="https://example.com" />
        </view>

        <view class="form-item">
          <text class="label">Logo 地址</text>
          <input v-model="form.logoUrl" placeholder="请输入企业 Logo 图片链接" />
        </view>
      </view>

      <view class="card">
        <view class="section-title">企业介绍</view>

        <view class="form-item">
          <text class="label">公司简介</text>
          <textarea v-model="form.description" class="textarea-field" maxlength="500" auto-height placeholder="请补充公司介绍、主营业务与团队特点" />
        </view>

        <view class="form-item">
          <text class="label">福利亮点</text>
          <textarea v-model="form.benefits" class="textarea-field" maxlength="300" auto-height placeholder="如：六险一金、弹性办公、年度体检等" />
        </view>
      </view>

      <button class="primary" :disabled="saving" @click="handleSave">
        {{ saving ? '保存中...' : '保存企业资料' }}
      </button>
    </template>
  </view>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import { onMounted, onShow } from '@dcloudio/uni-app';
import { getHrInfo } from '@/services/api/hr';
import { getCompanyById, updateCompanyInfo, type UpdateCompanyInfoParams } from '@/services/api/company';
import { useHrStore } from '@/store/hr';

interface CompanyFormState {
  companyName: string;
  description: string;
  companyScale: number;
  financingStage: number;
  industry: string;
  website: string;
  logoUrl: string;
  benefits: string;
  companyCreatedAt: string;
  registeredCapital: string;
}

const companyScaleOptions = [
  { label: '少于 15 人', value: 0 },
  { label: '15-50 人', value: 1 },
  { label: '50-150 人', value: 2 },
  { label: '150-500 人', value: 3 },
  { label: '500-2000 人', value: 4 },
  { label: '2000 人以上', value: 5 },
];

const financingStageOptions = [
  { label: '未融资', value: 0 },
  { label: '天使轮', value: 1 },
  { label: 'A 轮', value: 2 },
  { label: 'B 轮', value: 3 },
  { label: 'C 轮及以上', value: 4 },
  { label: '已上市', value: 5 },
];

const form = ref<CompanyFormState>({
  companyName: '',
  description: '',
  companyScale: -1,
  financingStage: -1,
  industry: '',
  website: '',
  logoUrl: '',
  benefits: '',
  companyCreatedAt: '',
  registeredCapital: '',
});

const companyId = ref<number | null>(null);
const loading = ref(false);
const saving = ref(false);
const hrStore = useHrStore();

const companyScaleIndex = computed(() => {
  const index = companyScaleOptions.findIndex(option => option.value === form.value.companyScale);
  return index === -1 ? 0 : index;
});

const financingStageIndex = computed(() => {
  const index = financingStageOptions.findIndex(option => option.value === form.value.financingStage);
  return index === -1 ? 0 : index;
});

const selectedScaleLabel = computed(() => {
  return companyScaleOptions.find(option => option.value === form.value.companyScale)?.label || '请选择公司规模';
});

const selectedFinancingLabel = computed(() => {
  return financingStageOptions.find(option => option.value === form.value.financingStage)?.label || '请选择融资阶段';
});

const normalizeDate = (value?: string) => {
  if (!value) return '';
  return String(value).slice(0, 10);
};

const fillForm = (data: Partial<UpdateCompanyInfoParams>) => {
  form.value = {
    companyName: data.companyName || '',
    description: data.description || '',
    companyScale: typeof data.companyScale === 'number' ? data.companyScale : -1,
    financingStage: typeof data.financingStage === 'number' ? data.financingStage : -1,
    industry: data.industry || '',
    website: data.website || '',
    logoUrl: data.logoUrl || '',
    benefits: data.benefits || '',
    companyCreatedAt: normalizeDate(data.companyCreatedAt),
    registeredCapital: data.registeredCapital !== undefined && data.registeredCapital !== null ? String(data.registeredCapital) : '',
  };
};

const loadCompany = async () => {
  loading.value = true;
  try {
    const hrInfo = await getHrInfo();
    companyId.value = hrInfo.companyId ?? null;
    hrStore.setCompanyId(hrInfo.companyId ?? null);
    hrStore.setCompanyName(hrInfo.companyName || '');

    if (!companyId.value) {
      fillForm({});
      return;
    }

    const company = await getCompanyById(companyId.value);
    fillForm(company);
  } catch (error) {
    console.error('Failed to load company info:', error);
    uni.showToast({ title: '企业资料加载失败', icon: 'none' });
  } finally {
    loading.value = false;
  }
};

const onCompanyScaleChange = (event: { detail: { value: number } }) => {
  const option = companyScaleOptions[event.detail.value];
  if (option) {
    form.value.companyScale = option.value;
  }
};

const onFinancingStageChange = (event: { detail: { value: number } }) => {
  const option = financingStageOptions[event.detail.value];
  if (option) {
    form.value.financingStage = option.value;
  }
};

const onDateChange = (event: { detail: { value: string } }) => {
  form.value.companyCreatedAt = event.detail.value;
};

const validateForm = () => {
  if (!form.value.companyName.trim()) return '请输入企业名称';
  if (!form.value.industry.trim()) return '请输入行业方向';
  if (form.value.companyScale < 0) return '请选择公司规模';
  if (form.value.financingStage < 0) return '请选择融资阶段';
  if (!form.value.description.trim()) return '请输入公司简介';
  if (!form.value.companyCreatedAt) return '请选择成立时间';
  if (!form.value.registeredCapital.trim()) return '请输入注册资本';
  if (Number.isNaN(Number(form.value.registeredCapital))) return '注册资本格式不正确';
  return '';
};

const handleSave = async () => {
  if (!companyId.value) {
    uni.showToast({ title: '当前账号未关联企业', icon: 'none' });
    return;
  }

  const validationMessage = validateForm();
  if (validationMessage) {
    uni.showToast({ title: validationMessage, icon: 'none' });
    return;
  }

  saving.value = true;
  try {
    const payload: UpdateCompanyInfoParams = {
      companyName: form.value.companyName.trim(),
      description: form.value.description.trim(),
      companyScale: form.value.companyScale,
      financingStage: form.value.financingStage,
      industry: form.value.industry.trim(),
      website: form.value.website.trim(),
      logoUrl: form.value.logoUrl.trim(),
      benefits: form.value.benefits.trim(),
      companyCreatedAt: form.value.companyCreatedAt,
      registeredCapital: Number(form.value.registeredCapital),
    };

    await updateCompanyInfo(companyId.value, payload);
    hrStore.setCompanyName(payload.companyName);
    uni.showToast({ title: '企业资料已保存', icon: 'success' });
    await loadCompany();
  } catch (error) {
    console.error('Failed to update company info:', error);
    uni.showToast({ title: '保存失败', icon: 'none' });
  } finally {
    saving.value = false;
  }
};

onMounted(() => {
  loadCompany();
});

onShow(() => {
  loadCompany();
});
</script>

<style scoped lang="scss">
.company-page {
  min-height: 100vh;
  padding: 24rpx;
  background: linear-gradient(180deg, #eef4ff 0%, #f7f9fc 32%, #f7f9fc 100%);
  box-sizing: border-box;
}

.card {
  background: #ffffff;
  border-radius: 24rpx;
  padding: 28rpx;
  margin-bottom: 24rpx;
  box-shadow: 0 12rpx 32rpx rgba(15, 23, 42, 0.05);
}

.overview-card {
  background: linear-gradient(135deg, #2f7cff 0%, #66a6ff 100%);
  color: #ffffff;
}

.overview-label {
  font-size: 24rpx;
  opacity: 0.88;
}

.overview-title {
  margin-top: 12rpx;
  font-size: 40rpx;
  font-weight: 700;
}

.overview-meta {
  margin-top: 16rpx;
  display: flex;
  flex-wrap: wrap;
  gap: 12rpx;
  font-size: 24rpx;
  opacity: 0.92;
}

.section-title {
  font-size: 30rpx;
  font-weight: 600;
  color: #111827;
  margin-bottom: 18rpx;
}

.form-item {
  margin-bottom: 22rpx;
}

.label {
  display: block;
  margin-bottom: 10rpx;
  color: #6b7280;
  font-size: 24rpx;
}

input,
.picker-field,
.textarea-field {
  width: 100%;
  box-sizing: border-box;
  background: #f5f7fb;
  border-radius: 16rpx;
  border: none;
}

input,
.picker-field {
  min-height: 84rpx;
  padding: 0 22rpx;
  display: flex;
  align-items: center;
  color: #111827;
}

.picker-field {
  line-height: 84rpx;
  color: #111827;
}

.textarea-field {
  min-height: 200rpx;
  padding: 22rpx;
  color: #111827;
}

.status-card {
  display: flex;
  justify-content: center;
  align-items: center;
  min-height: 240rpx;
}

.status-text {
  font-size: 28rpx;
  line-height: 1.7;
  color: #6b7280;
  text-align: center;
}

.primary {
  width: 100%;
  height: 92rpx;
  border: none;
  border-radius: 18rpx;
  background: #2f7cff;
  color: #ffffff;
  font-size: 30rpx;
}
</style>
