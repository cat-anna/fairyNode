<template>
    <va-card>
        <va-card-title>{{ t('dashboard.deviceTable.title') }}</va-card-title>
        <va-card-content>
            <div class="table-wrapper">
                <table class="va-table va-table--striped va-table--hoverable">
                    <thead>
                        <tr>
                            <th>Name</th>
                            <th>Status</th>
                            <th>Error</th>
                            <th>Uptime</th>
                            <!-- <th>Country</th> -->
                        </tr>
                    </thead>

                    <tbody>
                        <tr v-for="device in deviceData" :key="device.device_id">
                            <td>
                                <router-link style="text-decoration: none; color: inherit;"
                                    :to="{ path: '/admin/devices/' + device.device_id, params: { device_id: device.device_id } }">
                                    {{ device.name }}
                                </router-link>
                            </td>
                            <td><va-badge :text="device.status" :color="getStatusColor(device.status)" /></td>
                            <td><va-badge :text="device.errors" color="danger" v-if="device.errors > 0" /></td>
                            <td>{{ formatSeconds(device.uptime) }}</td>
                            <!-- <td>{{ user.country }}</td> -->
                        </tr>
                    </tbody>
                </table>
            </div>
        </va-card-content>
    </va-card>
</template>

<script lang="ts">
import { useI18n } from 'vue-i18n'
import deviceService from '../../../services/fairyNode/DeviceService'
import dashboardService from '../../../services/fairyNode/DashboardService'
import { SummaryDeviceEntry } from '../../../services/fairyNode/DeviceService'
import formatting from '../../../services/fairyNode/Formatting'

export default {
    deviceService,
    formatting,

    setup() {
        const { t } = useI18n()
        return { t }
    },
    data() {
        return {
            deviceData: Array<SummaryDeviceEntry>(),
            timerId: 0,
        }
    },
    mounted() {
        this.getData()
        if (this.timerId == 0) {
            this.timerId = window.setInterval(() => { this.getData() }, 5 * 1000)
        }
    },
    unmounted() {
        if (this.timerId != 0) {
            window.clearInterval(this.timerId)
            this.timerId = 0
        }
    },

    methods: {
        getStatusColor(v: string) { return deviceService.getStatusColor(v) },
        formatSeconds(v: number) { return formatting.formatSeconds(v) },

        getData() {
            dashboardService.summary().then(data => this.deviceData = data)
        }
    },
}
</script>

<style lang="scss">
.table-wrapper {
    .va-table {
        width: 100%;
    }
}
</style>
