
<template>
    <OrbitSpinner v-if="!idle" :size="16" />
    <va-button v-if="!editing && idle" @click="beginEdit" plain>
        <va-icon :name='"material-icons-edit"' />
    </va-button>

    <va-counter v-if="editing" v-model="pending_value" buttons manual-input style="width: 300px;">
        <template #decreaseAction>
            <va-button-group plain>
                <va-button @click="cancelEdit"><va-icon :name='"material-icons-cancel"' /></va-button>
                <va-button v-for="step in steps" :key="step" class="!px-0" @click="updateValue(-step)">
                    -{{ step }}
                </va-button>
            </va-button-group>
        </template>
        <template #increaseAction>
            <va-button-group plain>
                <va-button v-for="step in steps" :key="step" class="!px-0" @click="updateValue(step)">
                    +{{ step }}
                </va-button>
                <va-button @click="applyEdit"><va-icon :name='"material-icons-done"' /></va-button>
            </va-button-group>
        </template>
    </va-counter>
</template>

<style></style>

<script lang="ts">
import { useI18n } from 'vue-i18n'
import deviceService from '../../../../services/fairyNode/DeviceService'
import { OrbitSpinner } from 'epic-spinners'
import { useToast } from 'vuestic-ui'

export default {
    components: {
        OrbitSpinner,
    },
    props: {
        device_id: String,
        node_id: String,
        prop_id: String,
        value: Number
    },
    emits: ["changed"],
    setup(Properties, { emit }) {
        const { init, close, closeAll } = useToast()
        const { t } = useI18n()
        return { t, emit, toastShow: init, }
    },
    data() {
        return {
            idle: true,
            editing: false,
            steps: [0.01, 10],
            pending_value: 0.0,
        }
    },
    methods: {
        beginEdit() {
            if (this.value == null) {
                return
            }
            this.pending_value = this.value
            this.editing = true
        },
        updateValue(step: number) {
            this.pending_value += step
            this.pending_value = parseFloat(this.pending_value.toFixed(3))
        },
        cancelEdit() {
            this.editing = false
        },
        applyEdit() {
            if (this.device_id && this.node_id && this.prop_id) {
                this.idle = false
                deviceService.setProperty(this.device_id, this.node_id, this.prop_id, this.pending_value)
                    .then(() => this.toastShow({
                        message: this.t("deviceInfo.nodes.setSuccess"),
                        color: 'success'
                    }))
                    .catch(() => this.toastShow({
                        message: this.t("deviceInfo.nodes.setFailure"),
                        color: 'warning'
                    }))
                    .finally(() => {
                        this.idle = true
                        this.emit('changed')
                    })
            }
            this.editing = false
        },
    }
}
</script>

