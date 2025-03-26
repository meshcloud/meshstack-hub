import { CommonModule } from '@angular/common';
import { Component, Input } from '@angular/core';
import { Router, RouterModule } from '@angular/router';

@Component({
  selector: 'mst-card',
  imports: [RouterModule, CommonModule],
  templateUrl: './card.component.html',
  styleUrl: './card.component.scss',
  standalone: true
})
export class CardComponent {
  @Input()
  public imageUrl: string| null = null;

  @Input()
  public platformType!: string;

  @Input()
  public title!: string;

  @Input()
  public description!: string;

  @Input()
  public date: string | null = null;

  @Input()
  public detailsRoute!: string;

  constructor(private router: Router) {}

  public goToDetails() {
    // TODO this.router.navigate([this.detailsRoute]);
  }
}

