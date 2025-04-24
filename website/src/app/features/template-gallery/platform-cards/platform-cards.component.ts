import { CommonModule } from '@angular/common';
import { Component, Input } from '@angular/core';

import { CardComponent } from 'app/shared/card';
import { LogoCircleComponent } from 'app/shared/logo-circle';

import { PlatformCard } from './platform-card';

@Component({
  selector: 'mst-platform-cards',
  imports: [CommonModule, CardComponent, LogoCircleComponent],
  templateUrl: './platform-cards.component.html',
})
export class PlatformCardsComponent {
  @Input()
  public cards!: PlatformCard[];
}
