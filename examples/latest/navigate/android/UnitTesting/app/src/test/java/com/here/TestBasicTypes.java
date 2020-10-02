/*
 * Copyright (C) 2019-2020 HERE Europe B.V.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * SPDX-License-Identifier: Apache-2.0
 * License-Filename: LICENSE
 */

package com.here;

import com.here.sdk.core.Angle;

import org.junit.Test;
import org.junit.runner.RunWith;
import org.mockito.junit.MockitoJUnitRunner;

import static junit.framework.TestCase.assertEquals;
import static org.mockito.ArgumentMatchers.anyDouble;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoMoreInteractions;
import static org.mockito.Mockito.when;

@RunWith(MockitoJUnitRunner.class)
public class TestBasicTypes {

    @Test
    public void testNonStaticMethod() {
        Angle angleMock = mock(Angle.class);

        when(angleMock.getDegrees()).thenReturn(10.0);

        assertEquals(10.0, angleMock.getDegrees());
        verify(angleMock, times(1)).getDegrees();
        verifyNoMoreInteractions(angleMock);
    }

    @Test
    public void testStaticMethod() {
        Angle angleMock = mock(Angle.class);
        when(angleMock.getDegrees()).thenReturn(10.0);

        // Each class with static methods has helper code to make mocking easier.
        Angle.StaticMockHelperInstance = mock(Angle.StaticMockHelper.class);
        when(Angle.StaticMockHelperInstance.fromRadians(anyDouble())).thenReturn(angleMock);

        assertEquals(10.0, Angle.fromRadians(4.2).getDegrees());

        verify(Angle.StaticMockHelperInstance, times(1)).fromRadians(anyDouble());
        verify(angleMock, times(1)).getDegrees();
        verifyNoMoreInteractions(Angle.StaticMockHelperInstance);
        verifyNoMoreInteractions(angleMock);
    }
}
