<template>
  <div>
    <va-card v-if="!supported" class="node-card mb-8">
      <va-card-content>
        {{ t('deviceInfo.software.notSupported') }}
      </va-card-content>
    </va-card>
    <div v-else>
      <device-software-actions :device-id="deviceId" />
      <device-software-status :device-id="deviceId" />
      <device-software-commits :device-id="deviceId" />
    </div>
  </div>
</template>

<script lang="ts">
  import { useI18n } from 'vue-i18n'
  import { defineComponent } from 'vue'
  import { useModal, useToast } from 'vuestic-ui'
  import formatting from '../../../services/fairyNode/Formatting'

  import DeviceSoftwareCommits from './software/DeviceSoftwareCommits.vue'
  import DeviceSoftwareStatus from './software/DeviceSoftwareStatus.vue'
  import DeviceSoftwareActions from './software/DeviceSoftwareActions.vue'

  export default defineComponent({
    components: {
      DeviceSoftwareActions,
      DeviceSoftwareStatus,
      DeviceSoftwareCommits,
    },
    props: {
      deviceId: { type: String, required: true },
      supported: { type: Boolean, required: true },
    },
    setup() {
      const { init } = useToast()
      const { confirm } = useModal()
      const { t } = useI18n()

      return {
        showModalConfirm: confirm,
        toastShow: init,
        t: t,
        formatting: formatting,
      }
    },
  })
</script>
<style lang="scss"></style>
