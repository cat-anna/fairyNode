<template>
    <div class="markup-tables flex">

        <va-card class="node-card">
            <va-card-title>{{ t("deviceInfo.software.commits") }}</va-card-title>

            <va-card-content v-if="softwareData == null">
                {{ t("deviceInfo.software.notSupported") }}
            </va-card-content>

            <va-card-content v-if="softwareData">
                <div class="table-wrapper">
                    <table class="va-table va-table--striped va-table--hoverable">
                        <colgroup>
                            <col style="width:5%">
                            <col style="width:5%">
                            <col style="width:10%">
                            <col style="width:10%">
                            <col style="width:20%">
                            <col style="width:10%">
                            <col style="width:20%">
                            <col style="width:50%">
                        </colgroup>
                        <thead>
                            <tr>
                                <th>  </th>
                                <th> {{ t("deviceInfo.software.commit.current") }} </th>
                                <th> {{ t("deviceInfo.software.commit.id") }} </th>
                                <th> {{ t("deviceInfo.software.commit.bootSuccessful") }} </th>
                                <th> {{ t("deviceInfo.software.commit.timestamp") }} </th>
                                <th>&nbsp;</th>
                                <th> {{ t("deviceInfo.software.commit.actions") }} </th>
                                <th></th>
                            </tr>
                        </thead>
                        <tbody>
                            <tr v-for="(commit, prop_key) in softwareData.commits">
                                <td>
                                    <VaPopover v-if="commit.key == softwareData.active"
                                        :message="t('deviceInfo.software.help.commitIsActive')">
                                        <va-icon :name='"material-icons-arrow_forward"' />
                                    </VaPopover>
                                </td>
                                <td>
                                    <VaPopover :message="t('deviceInfo.software.help.commitIsCurrent')"
                                        v-if="commit.key == softwareData.current">
                                        <va-icon :name='"material-icons-memory"' />
                                    </VaPopover>
                                </td>
                                <td>
                                    <VaPopover :message="commit.key">
                                        {{ commit.key.substring(0, 8) }}
                                    </VaPopover>
                                </td>
                                <td>
                                    <VaPopover :message="t('deviceInfo.software.help.commitBootSuccessful')"
                                        v-if="commit.boot_successful">
                                        <va-icon :name='"material-icons-check"' />
                                    </VaPopover>
                                </td>
                                <td> {{ formatting.formatTimestamp(commit.timestamp) }} </td>
                                <td>
                                    <OrbitSpinner :size="16"
                                        v-if="activationIsBlocked && selectedCommit && selectedCommit.key == commit.key" />
                                </td>
                                <td>
                                    <VaPopover :message="t('deviceInfo.software.help.activateCommit')">
                                        <va-button @click="confirmActivateSoftware(commit)"
                                            :disabled="(commit.key == softwareData.active) || activationIsBlocked"
                                            preset="plain" size="small">
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
            <va-card-content v-if="fetchingData && softwareData==null">
                <OrbitSpinner />
            </va-card-content>
        </va-card>
    </div>
</template>

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

<!--

export default defineComponent({
  setup() {

    return {
      onButtonClick: () => {
        confirm('Are you sure you want to see standard alert?')
          .then((ok) => ok && alert('This is standard browser alert'))
      },
    }
  }
}) -->

<script lang="ts">
import { useI18n } from 'vue-i18n'
import { defineComponent } from 'vue'
import { useModal } from 'vuestic-ui'
import firmwareService from '../../../services/fairyNode/FirmwareService'
import { DeviceCommitStatus, DeviceCommit } from '../../../services/fairyNode/FirmwareService'
import formatting from '../../../services/fairyNode/Formatting'
import dataTypes from '../../../services/fairyNode/DataTypes'
import { ref } from 'vue'
import { OrbitSpinner } from 'epic-spinners'

export declare type OptionalDeviceCommit = null | DeviceCommit;
export declare type OptionalDeviceCommitStatus = null | DeviceCommitStatus;

export default defineComponent({
    components: {
        OrbitSpinner,
    },
    props: {
        device_id: String,
    },
    watch: {
        async device_id() {
            this.softwareData = null
            this.getData()
        }
    },
    setup() {
        const softwareData = ref(<OptionalDeviceCommitStatus>{})
        const selectedCommit = ref(<OptionalDeviceCommit>{})

        const { confirm } = useModal()
        const { t } = useI18n()

        return { t, softwareData, formatting, selectedCommit,
             showModalConfirm: confirm  }
    },
    data() {
        return {
            timerId: 0,
            dataTypes: dataTypes,
            activationIsBlocked: false,
            fetchingData: false
        }
    },

    mounted() {
        if (this.timerId == 0) {
            this.timerId = window.setInterval(() => { this.getData() }, 30 * 1000)
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
            if (this.selectedCommit && this.device_id) {
                console.log(this.device_id)
                firmwareService.activateCommitForDevice(this.device_id, this.selectedCommit.key)
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
            if (this.device_id) {
                this.fetchingData = true
                firmwareService.listCommitsForDevice(this.device_id)
                    .then((data) => {
                        data.commits.sort(function (a, b) {
                            return a.timestamp - b.timestamp
                        })
                        this.softwareData = data
                    })
                    .catch(() => { this.softwareData = null })
                    .finally(() => this.fetchingData = false)

            }
        }
    }
})
</script>