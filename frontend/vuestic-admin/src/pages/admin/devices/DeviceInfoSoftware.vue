<template>
  <div class="markup-tables">
    <va-card class="node-card">
      <va-card-title>{{ t('deviceInfo.software.commits') }}</va-card-title>

      <va-card-content v-if="softwareData == null">
        {{ t('deviceInfo.software.notSupported') }}
      </va-card-content>

      <va-card-content v-if="softwareData">
        <div class="table-wrapper">
          <table class="va-table va-table--striped va-table--hoverable">
            <colgroup>
              <col style="width: 5%" />
              <col style="width: 5%" />
              <col style="width: 10%" />
              <col style="width: 10%" />
              <col style="width: 20%" />
              <col style="width: 10%" />
              <col style="width: 20%" />
              <col style="width: 50%" />
            </colgroup>
            <thead>
              <tr>
                <th></th>
                <th>{{ t('deviceInfo.software.commit.current') }}</th>
                <th>{{ t('deviceInfo.software.commit.id') }}</th>
                <th>{{ t('deviceInfo.software.commit.bootSuccessful') }}</th>
                <th>{{ t('deviceInfo.software.commit.timestamp') }}</th>
                <th>&nbsp;</th>
                <th>{{ t('deviceInfo.software.commit.actions') }}</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(commit, propKey) in softwareData.commits" :key="propKey">
                <td>
                  <VaPopover
                    v-if="commit.key == softwareData.active"
                    :message="t('deviceInfo.software.help.commitIsActive')"
                  >
                    <va-icon :name="'material-icons-arrow_forward'" />
                  </VaPopover>
                </td>
                <td>
                  <VaPopover
                    v-if="commit.key == softwareData.current"
                    :message="t('deviceInfo.software.help.commitIsCurrent')"
                  >
                    <va-icon :name="'material-icons-memory'" />
                  </VaPopover>
                </td>
                <td>
                  <VaPopover :message="commit.key">
                    {{ commit.key.substring(0, 8) }}
                  </VaPopover>
                </td>
                <td>
                  <VaPopover
                    v-if="commit.boot_successful"
                    :message="t('deviceInfo.software.help.commitBootSuccessful')"
                  >
                    <va-icon :name="'material-icons-check'" />
                  </VaPopover>
                </td>
                <td>{{ formatting.formatTimestamp(commit.timestamp) }}</td>
                <td>
                  <OrbitSpinner
                    v-if="activationIsBlocked && selectedCommit && selectedCommit.key == commit.key"
                    :size="16"
                  />
                </td>
                <td>
                  <VaPopover :message="t('deviceInfo.software.help.activateCommit')">
                    <va-button
                      :disabled="commit.key == softwareData.active || activationIsBlocked"
                      preset="plain"
                      size="small"
                      @click="confirmActivateSoftware(commit)"
                    >
                      {{ t('deviceInfo.software.activate') }}
                    </va-button>
                  </VaPopover>
                </td>
                <td></td>
              </tr>
            </tbody>
          </table>
        </div>
      </va-card-content>
      <va-card-content v-if="fetchingData && softwareData == null">
        <OrbitSpinner />
      </va-card-content>
    </va-card>
  </div>
</template>

<script lang="ts">
  import { useI18n } from 'vue-i18n'
  import { defineComponent, ref } from 'vue'
  import { useModal, useToast } from 'vuestic-ui'
  import firmwareService from '../../../services/fairyNode/FirmwareService'
  import { DeviceCommitStatus, DeviceCommit } from '../../../services/fairyNode/FirmwareService'
  import formatting from '../../../services/fairyNode/Formatting'
  import dataTypes from '../../../services/fairyNode/DataTypes'
  import { OrbitSpinner } from 'epic-spinners'

  export declare type OptionalDeviceCommit = null | DeviceCommit
  export declare type OptionalDeviceCommitStatus = null | DeviceCommitStatus

  export default defineComponent({
    components: {
      OrbitSpinner,
    },
    props: {
      deviceId: { type: String, required: true },
    },
    setup() {
      const softwareData = ref(<OptionalDeviceCommitStatus>{})
      const selectedCommit = ref(<OptionalDeviceCommit>{})

      const { init } = useToast()
      const { confirm } = useModal()
      const { t } = useI18n()

      return {
        showModalConfirm: confirm,
        toastShow: init,
        t: t,
        softwareData: softwareData,
        formatting: formatting,
        selectedCommit: selectedCommit,
      }
    },
    data() {
      return {
        timerId: 0,
        dataTypes: dataTypes,
        activationIsBlocked: false,
        fetchingData: false,
      }
    },
    watch: {
      async deviceId() {
        this.softwareData = null
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
      cancelActivation() {
        this.selectedCommit = null
        this.activationIsBlocked = false
      },
      activateSoftware() {
        if (this.selectedCommit && this.deviceId) {
          console.log(this.deviceId)
          firmwareService
            .activateCommitForDevice(this.deviceId, this.selectedCommit.key)
            .then(() =>
              this.toastShow({
                message: this.t('deviceInfo.software.activateSuccess'),
                color: 'success',
              }),
            )
            .catch(() =>
              this.toastShow({
                message: this.t('deviceInfo.software.activateFailure'),
                color: 'warning',
              }),
            )
            .finally(() => {
              this.activationIsBlocked = false
              this.getData()
            })
        }
      },
      confirmActivateSoftware(commit: DeviceCommit) {
        this.selectedCommit = commit
        this.activationIsBlocked = true
        this.showModalConfirm({
          message: this.t('deviceInfo.software.activateConfirmationMessage'),
          blur: true,
          onOk: () => this.activateSoftware(),
          onCancel: () => this.cancelActivation(),
        })
      },
      async getData() {
        if (this.deviceId) {
          this.fetchingData = true
          firmwareService
            .listCommitsForDevice(this.deviceId)
            .then((data) => {
              data.commits.sort(function (a, b) {
                return a.timestamp - b.timestamp
              })
              this.softwareData = data
            })
            .catch(() => {
              this.softwareData = null
            })
            .finally(() => (this.fetchingData = false))
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
