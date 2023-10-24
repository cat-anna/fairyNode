
<template>
    <OrbitSpinner v-if="!idle" :size="16" />
    <va-button v-if="!editing && idle" @click="beginEdit" plain>
        <va-icon :name='"material-icons-edit"' />
    </va-button>


    <va-input v-if="editing" v-model="pending_value" class="mb-6" style="width: 200px;">
        <template #prepend>
            <va-button plain @click="applyEdit"><va-icon :name='"material-icons-done"' /></va-button>
        </template>
        <template #append>
            <va-button plain @click="cancelEdit"><va-icon :name='"material-icons-cancel"' /></va-button>
        </template>
    </va-input>
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
        value: String
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
            pending_value: "",
        }
    },
    methods: {
        beginEdit() {
            this.pending_value = ""
            if (this.value != null) {
                this.pending_value = this.value
            }
            this.editing = true
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

