<template>
  <device-details-actions :device-id="deviceId" />
  <device-details-software :device-id="deviceId" />
  <device-details-variables :device-id="deviceId" />
</template>

<script lang="ts">
  import { useI18n } from 'vue-i18n'
  import { defineComponent } from 'vue'

  import DeviceDetailsVariables from './details/DeviceDetailsVariables.vue'
  import DeviceDetailsSoftware from './details/DeviceDetailsSoftware.vue'
  import DeviceDetailsActions from './details/DeviceDetailsActions.vue'

  export default defineComponent({
    components: {
      DeviceDetailsVariables,
      DeviceDetailsSoftware,
      DeviceDetailsActions,
    },
    props: {
      deviceId: { type: String, required: true },
    },
    setup() {
      const { t } = useI18n()
      return { t }
    },
  })
</script>

<style lang="scss">
  .table-wrapper {
    overflow: auto;
    table-layout: fixed;

    .va-table {
      width: 100%;
    }
  }
</style>
