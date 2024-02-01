<template>
  <va-card class="mb-8">
    <va-card-title> {{ t('deviceInfo.status') }} </va-card-title>
    <va-card-content class="space-y-2">
      <div class="flex">
        <div class="mx-2">{{ summary.device_id }}</div>
        <div class="mx-2">{{ summary.hardware_id }}</div>
        <div class="mx-2">{{ summary.name }}</div>
      </div>

      <div class="flex">
        <div class="mx-2"><va-badge :text="summary.status" :color="getStatusColor(summary.status)" /></div>
        <div v-if="summary.is_fairy_node" class="mx-2">{{ t('deviceInfo.fairyNodeDevice') }}</div>
      </div>
    </va-card-content>
  </va-card>
  <va-card class="mb-4">
    <va-card-title> {{ t('deviceInfo.title') }} </va-card-title>
    <va-card-content>
      <va-tabs v-model="activeTabName" grow>
        <template #tabs>
          <va-tab name="DeviceInfoNodesTab"> {{ t('deviceInfo.nodes.tabTitle') }} </va-tab>
          <va-tab name="DeviceInfoSoftwareTab"> {{ t('deviceInfo.software.tabTitle') }} </va-tab>
          <va-tab name="DeviceInfoDetails"> {{ t('deviceInfo.details.tabTitle') }} </va-tab>
        </template>
      </va-tabs>
    </va-card-content>
  </va-card>

  <device-info-nodes v-if="activeTabName == 'DeviceInfoNodesTab'" :device-id="deviceId" />
  <device-info-software v-if="activeTabName == 'DeviceInfoSoftwareTab'" :device-id="deviceId" :supported="summary.is_fairy_node" />
  <device-info-details v-if="activeTabName == 'DeviceInfoDetails'" :device-id="deviceId" />
</template>

<script lang="ts">
  import { ref, defineComponent } from 'vue'
  import { useI18n } from 'vue-i18n'
  import { useRoute } from 'vue-router'

  import DeviceInfoNodes from './DeviceInfoNodes.vue'
  import DeviceInfoSoftware from './DeviceInfoSoftware.vue'
  import DeviceInfoDetails from './DeviceInfoDetails.vue'

  import deviceService from '../../../services/fairyNode/DeviceService'
  import { SummaryDeviceEntry } from '../../../services/fairyNode/DeviceService'

  export default defineComponent({
    components: {
      DeviceInfoNodes,
      DeviceInfoSoftware,
      DeviceInfoDetails,
    },
    beforeRouteUpdate(to: any, from: any, next) {
      this.deviceId = to.params.deviceId as string
      this.getData()
      next()
    },
    setup() {
      const route = useRoute()
      const deviceId = ref(route.params.deviceId as string)
      const summary = ref(<SummaryDeviceEntry>{})

      const { t } = useI18n()
      return {
        t: t,
        deviceId: deviceId,
        summary: summary,
      }
    },
    data() {
      return {
        timerId: 0,
        activeTabName: ref('DeviceInfoNodesTab'),
      }
    },

    mounted() {
      this.deviceId = this.$route.params.deviceId as string
      if (this.timerId == 0) {
        this.timerId = window.setInterval(() => {
          this.getData()
        }, 10 * 1000)
      }
      this.getData()
    },
    unmounted() {
      if (this.timerId != 0) {
        window.clearInterval(this.timerId)
        this.timerId = 0
      }
    },
    methods: {
      getStatusColor(v: string) {
        return deviceService.getStatusColor(v)
      },
      getData() {
        if (this.deviceId) {
          deviceService
            .deviceStatus(this.deviceId)
            .then((data) => {
              this.summary = data
            })
            .catch(() => {
              this.summary = <SummaryDeviceEntry>{}
              this.summary.is_fairy_node = false
            })
          // .finally(() => {})
        }
      },
    },
  })
</script>

<style lang="scss">
  .va-tabs__tabs {
    height: 100%;
  }
</style>
