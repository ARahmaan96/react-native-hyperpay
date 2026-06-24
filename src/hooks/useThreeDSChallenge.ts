import { useEffect, useState } from 'react';
import { eventEmitter } from '../utils';

export function useThreeDSChallenge() {
    const [isActive, setIsActive] = useState(false)

    useEffect(() => {
        const _event = eventEmitter.addListener('onThreeDSChallenge', (active: boolean) => {
            setIsActive(active)
        })
        return () => _event.remove()
    }, [])

    return isActive
}
