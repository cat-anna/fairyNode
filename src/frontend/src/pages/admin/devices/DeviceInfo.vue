<template>
  <br />
  <va-card>
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
  <va-separator />
  <device-info-nodes v-if="activeTabName == 'DeviceInfoNodesTab'" :device-id="deviceId" />
  <device-info-software v-if="activeTabName == 'DeviceInfoSoftwareTab'" :device-id="deviceId" :supported="true" />
  <device-info-details v-if="activeTabName == 'DeviceInfoDetails'" :device-id="deviceId" />
</template>

<script lang="ts">
  import { ref, defineComponent } from 'vue'
  import { useI18n } from 'vue-i18n'
  import { useRoute } from 'vue-router'

  import DeviceInfoNodes from './DeviceInfoNodes.vue'
  import DeviceInfoSoftware from './DeviceInfoSoftware.vue'
  import DeviceInfoDetails from './DeviceInfoDetails.vue'

  export default defineComponent({
    components: {
      DeviceInfoNodes,
      DeviceInfoSoftware,
      DeviceInfoDetails,
    },
    beforeRouteUpdate(to: any, from: any, next) {
      this.deviceId = to.params.deviceId as string
      next()
    },
    setup() {
      const route = useRoute()
      const deviceId = ref(route.params.deviceId as string)

      const { t } = useI18n()
      return { t, deviceId }
    },
    data() {
      return {
        activeTabName: ref('DeviceInfoNodesTab'),
      }
    },

    mounted() {
      this.deviceId = this.$route.params.deviceId as string
    },
    // unmounted() {},
    methods: {},
  })
</script>

<style lang="scss">
  .va-tabs__tabs {
    height: 100%;
  }
</style>
