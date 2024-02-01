<template>
  <va-card class="node-card mb-2">
    <va-card-title>{{ t('deviceInfo.software.status') }}</va-card-title>
    <va-card-content>
      <div v-if="displayCommits != null">
        <table class="va-table va-table--striped va-table--hoverable">
          <colgroup>
            <col style="width: 10%" />
            <col style="width: 10%" />
            <col style="width: 10%" />
            <col style="width: 20%" />
          </colgroup>
          <thead>
            <tr>
              <th>{{ t('deviceInfo.software.commit.id') }}</th>
              <th></th>
              <th>{{ t('deviceInfo.software.commit.bootSuccessful') }}</th>
              <th>{{ t('deviceInfo.software.commit.timestamp') }}</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="(commit, key) in displayCommits" :key="key">
              <td>
                <VaPopover :message="commit[1].key">
                  {{ commit[1].key.substring(0, 8) }}
                </VaPopover>
              </td>
              <td>
                <VaPopover v-if="commit[0] == 'current'" :message="t('deviceInfo.software.help.commitIsCurrent')">
                  <va-icon :name="'material-icons-memory'" />
                  {{ t('deviceInfo.software.commit.current') }}
                </VaPopover>
                <VaPopover v-if="commit[0] == 'active'" :message="t('deviceInfo.software.help.commitIsActive')">
                  <va-icon :name="'material-icons-arrow_forward'" />
                  {{ t('deviceInfo.software.commit.active') }}
                </VaPopover>
              </td>
              <td>
                <VaPopover v-if="commit[1].boot_successful" :message="t('deviceInfo.software.help.commitBootSuccessful')">
                  <va-icon :name="'material-icons-check'" />
                </VaPopover>
              </td>
              <td>{{ formatting.formatTimestamp(commit[1].timestamp) }}</td>
            </tr>
          </tbody>
        </table>
      </div>
      <busy-spinner v-else />
    </va-card-content>
  </va-card>
</template>

<script lang="ts">
  import { useI18n } from 'vue-i18n'
  import { defineComponent, ref } from 'vue'
  import { useModal, useToast } from 'vuestic-ui'
  import firmwareService from '../../../../services/fairyNode/FirmwareService'
  import { DeviceFirmwareStatusResponse, DeviceCommit } from '../../../../services/fairyNode/FirmwareService'
  import formatting from '../../../../services/fairyNode/Formatting'

  export declare type DeviceCommitMap = Map<string, DeviceCommit>
  export declare type OptionalDeviceFirmwareStatusResponse = null | DeviceFirmwareStatusResponse

  export default defineComponent({
    // components: {},
    props: {
      deviceId: { type: String, required: true },
    },
    setup() {
      const { init } = useToast()
      const { confirm } = useModal()
      const { t } = useI18n()

      const firmwareStatus = ref(<OptionalDeviceFirmwareStatusResponse>{})
      const displayCommits = ref(new Map<string, DeviceCommit>())

      return {
        showModalConfirm: confirm,
        toastShow: init,
        t: t,
        formatting: formatting,
        firmwareStatus: firmwareStatus,
        displayCommits: displayCommits,
      }
    },
    data() {
      return {
        timerId: 0,
      }
    },
    watch: {
      async deviceId() {
        this.firmwareStatus = null
        this.getData()
      },
    },

    mounted() {
      if (this.timerId == 0) {
        this.timerId = window.setInterval(() => {
          this.getData()
        }, 30 * 1000)
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
      async getData() {
        if (this.deviceId) {
          firmwareService.deviceStatus(this.deviceId).then((data) => {
            this.firmwareStatus = data
            this.displayCommits.clear()

            if (data.firmware.current) this.displayCommits.set('current', data.firmware.current)
            if (data.firmware.active) this.displayCommits.set('active', data.firmware.active)
          })
          // .catch(() => {})
        }
      },
    },
  })
</script>

<style lang="scss">
  .markup-tables {
    .table-wrapper {
      overflow: auto;
      table-layout: fixed;
    }

    .va-table {
      width: 100%;
      text-align: center;
      vertical-align: middle;
    }
  }
</style>
