<template>
    <va-card>
        <va-card-title>
            {{ t('deviceInfo.title') }}
        </va-card-title>
        <va-card-content>
            <va-tabs v-model="activeTabName" grow>
                <template #tabs>
                    <va-tab name="DeviceInfoNodesTab">
                        {{ t('deviceInfo.nodes.tabTitle') }}
                    </va-tab>
                    <va-tab name="DeviceInfoSoftwareTab">
                        {{ t('deviceInfo.software.tabTitle') }}
                    </va-tab>
                </template>
            </va-tabs>
        </va-card-content>
    </va-card>
    <va-separator />
    <DeviceInfoNodes v-if="activeTabName == 'DeviceInfoNodesTab'" />
    <DeviceInfoSoftware v-if="activeTabName == 'DeviceInfoSoftwareTab'" />
</template>

<style lang="scss">
.va-tabs__tabs {
    height: 100%;
}
</style>

<script lang="ts">
import { ref } from 'vue'
import { useI18n } from 'vue-i18n'

import DeviceInfoNodes from './DeviceInfoNodes.vue'
import DeviceInfoSoftware from './DeviceInfoSoftware.vue'

export default {
    components: {
        DeviceInfoNodes,
        DeviceInfoSoftware,
    },
    setup() {
        const { t } = useI18n()
        return { t }
    },
    data() {
        return {
            activeTabName: ref("DeviceInfoNodesTab")
        }
    },
    mounted() { },
    unmounted() { },
    methods: { }
}
</script>

<style lang="scss">
  .va-tabs__tabs {
    height: 100%;
  }
</style>
