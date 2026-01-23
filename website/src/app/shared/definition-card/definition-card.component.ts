import { CommonModule } from '@angular/common';
import { Component, Input } from '@angular/core';

import { CardComponent } from '../card';
import { DefinitionCard } from './definition-card';

@Component({
  selector: 'mst-definition-card',
  imports: [CommonModule, CardComponent],
  templateUrl: './definition-card.component.html',
  styleUrl: './definition-card.component.scss',
  standalone: true
})
export class DefinitionCardComponent {
  @Input()
  public card!: DefinitionCard;

}
