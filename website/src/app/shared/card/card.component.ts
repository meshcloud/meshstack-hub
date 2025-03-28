import { CommonModule } from '@angular/common';
import { Component, Input } from '@angular/core';
import { Router, RouterModule } from '@angular/router';

import { Card } from './card';

@Component({
  selector: 'mst-card',
  imports: [RouterModule, CommonModule],
  templateUrl: './card.component.html',
  styleUrl: './card.component.scss',
  standalone: true
})
export class CardComponent {
  @Input()
  public card!:Card;

  constructor(private router: Router) {}

  public goToDetails() {
    console.log('Navigating to details route', this.card.detailsRoute);
    this.router.navigate([this.card.detailsRoute]);
  }
}

