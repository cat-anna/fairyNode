<template>
    <div class="markup-tables flex">

        <OrbitSpinner v-if="softwareData.commits == null" />
        <va-card class="node-card" v-if="softwareData.commits != null">
            <va-card-title>{{ t("deviceInfo.software.commits") }}</va-card-title>

            <va-card-content>
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
                                <th> {{ t("deviceInfo.software.commit.active") }} </th>
                                <th> {{ t("deviceInfo.software.commit.current") }} </th>
                                <th> {{ t("deviceInfo.software.commit.id") }} </th>
                                <th> {{ t("deviceInfo.software.commit.boot_successful") }} </th>
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
                                        :message="t('deviceInfo.software.commit_is_active_help')">
                                        <va-icon :name='"material-icons-arrow_forward"' />
                                    </VaPopover>
                                </td>
                                <td>
                                    <VaPopover :message="t('deviceInfo.software.commit_is_current_help')"
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
                                    <VaPopover :message="t('deviceInfo.software.commit_boot_successful_help')"
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
                                    <VaPopover :message="t('deviceInfo.software.activate_commit_help')">
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
        </va-card>
    </div>

    <va-modal v-model="showActivateModal" :title="t('deviceInfo.software.activate-confirmation.title')"
        :message="t('deviceInfo.software.activate-confirmation.message')"
        :ok-text="t('deviceInfo.software.activate-confirmation.accept')"
        :cancel-text="t('deviceInfo.software.activate-confirmation.cancel')" @ok="activateSoftware"
        @cancel="cancelActivation" blur no-dismiss />
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

<script lang="ts">
import { useI18n } from 'vue-i18n'
import { defineComponent } from 'vue'
import firmwareService from '../../../services/fairyNode/FirmwareService'
import { DeviceCommitStatus, DeviceCommit } from '../../../services/fairyNode/FirmwareService'
import formatting from '../../../services/fairyNode/Formatting'
import dataTypes from '../../../services/fairyNode/DataTypes'
import { ref } from 'vue'
import { OrbitSpinner } from 'epic-spinners'

export declare type OptionalDeviceCommit = null | DeviceCommit;

export default defineComponent({
    components: {
        OrbitSpinner,
    },
    props: {
        device_id: String,
    },
    watch: {
        async hardware_id() {
            this.softwareData = <DeviceCommitStatus>{}
            this.getData()
        }
    },
    setup() {
        const softwareData = ref(<DeviceCommitStatus>{})
        const selectedCommit = ref(<OptionalDeviceCommit>{})
        const showActivateModal = ref(false)

        const { t } = useI18n()
        return { t, softwareData, formatting, selectedCommit, showActivateModal }
    },
    data() {
        return {
            timerId: 0,
            dataTypes: dataTypes,
            activationIsBlocked: false,
        }
    },

    mounted() {
        if (this.timerId == 0) {
            this.timerId = window.setInterval(() => { this.getData() }, 5 * 1000)
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
            this.showActivateModal = true
            this.activationIsBlocked = true
        },
        async getData() {
            if (this.device_id) {
                this.softwareData = await firmwareService.listCommitsForDevice(this.device_id)
                this.softwareData.commits.sort(function (a, b) {
                    a.timestamp < b.timestamp
                })
            }
        }
    }
})
</script>