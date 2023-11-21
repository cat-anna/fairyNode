<template>
  <va-card class="mb-2">
    <va-card-title>{{ t('deviceInfo.details.software.title') }}</va-card-title>

    <OrbitSpinner v-if="pending" />
    <span v-if="!valid"> {{ t('deviceInfo.details.software.invalid') }}</span>

    <div v-if="valid" class="table-wrapper">
      <va-card-content v-if="data && data.fairy_node">
        {{ t('deviceInfo.details.software.fairy_node_version') }}
        <table class="va-table va-table--striped va-table--hoverable">
          <colgroup>
            <col style="width: 20%" />
            <col style="width: 80%" />
          </colgroup>
          <tbody>
            <tr>
              <td>{{ t('deviceInfo.details.software.version') }}</td>
              <td>{{ data.fairy_node.version }}</td>
            </tr>
            <tr v-for="(value, key) in data.fairy_node.timestamps" :key="key">
              <td>{{ t('deviceInfo.details.software.component.' + key) }}</td>
              <td>{{ formatting.formatTimestamp(value) }}</td>
            </tr>
          </tbody>
        </table>
      </va-card-content>
      <va-card-content v-if="data && data.nodemcu">
        {{ t('deviceInfo.details.software.nodemcu_version') }}
        <table class="va-table va-table--striped va-table--hoverable">
          <colgroup>
            <col style="width: 20%" />
            <col style="width: 80%" />
          </colgroup>
          <tbody>
            <tr v-if="data.nodemcu.version">
              <td>{{ t('deviceInfo.details.software.version') }}</td>
              <td>{{ data.nodemcu.version }}</td>
            </tr>
            <tr v-if="data.nodemcu.branch">
              <td>{{ t('deviceInfo.details.software.branch') }}</td>
              <td>{{ data.nodemcu.branch }}</td>
            </tr>
            <tr v-if="data.nodemcu.release">
              <td>{{ t('deviceInfo.details.software.release') }}</td>
              <td>{{ data.nodemcu.release }}</td>
            </tr>
          </tbody>
        </table>
      </va-card-content>
    </div>
  </va-card>
</template>

<script lang="ts">
  import { useI18n } from 'vue-i18n'
  import { defineComponent, ref } from 'vue'
  import deviceService from '../../../../services/fairyNode/DeviceService'
  import { DeviceSoftwareInfo } from '../../../../services/fairyNode/DeviceService'
  import { OrbitSpinner } from 'epic-spinners'
  import formatting from '../../../../services/fairyNode/Formatting'

  export declare type OptionalDeviceSoftwareInfo = null | DeviceSoftwareInfo

  export default defineComponent({
    components: {
      OrbitSpinner,
    },
    props: {
      deviceId: {
        type: String,
        required: true,
      },
    },
    setup() {
      const data = ref(<OptionalDeviceSoftwareInfo>{})
      const { t } = useI18n()
      return { t, data, formatting }
    },
    data() {
      return {
        pending: true,
        valid: true,
      }
    },
    watch: {
      async deviceId() {
        this.data = null
        this.getData()
      },
    },
    mounted() {
      this.getData()
    },
    // unmounted() { },
    methods: {
      onChanged() {
        this.getData()
      },
      async getData() {
        this.pending = true
        deviceService
          .softwareInfo(this.deviceId)
          .then((data) => {
            this.valid = true
            this.data = data
            console.log(data)
          })
          .catch((error) => {
            this.data = null
            if (error.status == 400) {
              this.valid = false
            } else {
              //             //TODO
            }
          })
          .finally(() => {
            this.pending = false
          })
      },
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
